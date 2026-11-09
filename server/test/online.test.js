// Kiểm tra chơi online: node server/test/online.test.js
'use strict';
const http = require('http');
const assert = require('assert');
const online = require('../online.js');
const { Pos } = globalThis.XQ;

const send = (res, st, body) => { res.writeHead(st, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(body)); };
const srv = http.createServer((req, res) => { if (!online.handle(req, res, '1.2.3.4', send)) send(res, 404, {}); });

let base;
const post = async (p, body) => { const r = await fetch(base + '/api/online/' + p, { method: 'POST', body: JSON.stringify(body) }); return { st: r.status, ...(await r.json()) }; };
// người nghe SSE: giữ trạng thái mới nhất, chờ được điều kiện
function listen(room, token) {
  const L = { state: null, waiters: [] };
  L.req = http.get(base + '/api/online/events?room=' + room + '&token=' + token, (res) => {
    let buf = '';
    res.on('data', (d) => {
      buf += d;
      let i;
      while ((i = buf.indexOf('\n\n')) >= 0) {
        const chunk = buf.slice(0, i); buf = buf.slice(i + 2);
        const line = chunk.split('\n').find((l) => l.startsWith('data: '));
        if (!line) continue;
        L.state = JSON.parse(line.slice(6));
        L.waiters = L.waiters.filter(([f, ok]) => (f(L.state) ? (ok(L.state), false) : true));
      }
    });
  });
  L.until = (f, ms = 3000) => new Promise((ok, bad) => {
    if (L.state && f(L.state)) return ok(L.state);
    L.waiters.push([f, ok]);
    setTimeout(() => bad(new Error('timeout chờ trạng thái; cuối: ' + JSON.stringify(L.state))), ms);
  });
  L.close = () => L.req.destroy();
  return L;
}
const tok = (n) => ('token' + n).padEnd(20, 'x');
const mv = (moves, name) => { const p = Pos.start(); for (const m of moves) p.make(m); return p.legalMoves().find((m) => p.moveName(m) === name); };

(async () => {
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  base = 'http://127.0.0.1:' + srv.address().port;

  // ghép ngẫu nhiên: A chờ, B vào cùng phòng
  const a = await post('quick', { token: tok('A'), name: 'An', tc: '5+3' });
  assert.equal(a.st, 200);
  const LA = listen(a.room, tok('A'));
  await LA.until((s) => s.status === 'waiting' && s.online[a.side]);
  const b = await post('quick', { token: tok('B'), name: '<b>Bình</b>', tc: '5+3' });
  assert.equal(b.room, a.room, 'ghép vào cùng phòng');
  assert.notEqual(b.side, a.side);
  const LB = listen(b.room, tok('B'));
  const s0 = await LB.until((s) => s.status === 'playing');
  assert.equal(s0.names[b.side], 'bBình/b', 'bỏ ký tự < >');
  assert.equal(s0.you, b.side === 'r' ? 1 : -1);
  const red = a.side === 'r' ? 'A' : 'B', black = red === 'A' ? 'B' : 'A';

  // đi sai lượt, nước sai, rồi đi đúng
  let r = await post('act', { token: tok(black), room: a.room, act: 'move', move: mv([], 'Pháo 2 bình 5'), ply: 0 });
  assert.equal(r.st, 409);
  r = await post('act', { token: tok(red), room: a.room, act: 'move', move: 12345, ply: 0 });
  assert.equal(r.st, 409);
  const m1 = mv([], 'Pháo 2 bình 5');
  r = await post('act', { token: tok(red), room: a.room, act: 'move', move: m1, ply: 0 });
  assert.equal(r.st, 200);
  const s1 = await LA.until((s) => s.moves.length === 1);
  assert.equal(s1.running, 'b');
  assert.ok(s1.clock.r > 5 * 60e3 && s1.clock.r <= 5 * 60e3 + 3000, 'cộng giờ sau nước đi');
  // gửi lại cùng nước (trùng) bị từ chối
  r = await post('act', { token: tok(red), room: a.room, act: 'move', move: m1, ply: 0 });
  assert.equal(r.st, 409);
  // người xem
  const LW = listen(a.room, tok('W'));
  const sw = await LW.until((s) => s.moves.length === 1);
  assert.equal(sw.you, null);
  await LA.until((s) => s.watchers === 1);
  r = await post('act', { token: tok('W'), room: a.room, act: 'resign' });
  assert.equal(r.st, 403);

  // xin hòa → từ chối → xin lại → đồng ý
  await post('act', { token: tok(black), room: a.room, act: 'draw' });
  await LA.until((s) => s.drawOffer === 'b');
  await post('act', { token: tok(red), room: a.room, act: 'decline' });
  await LA.until((s) => s.drawOffer === null);
  await post('act', { token: tok(black), room: a.room, act: 'draw' });
  await post('act', { token: tok(red), room: a.room, act: 'accept' });
  const s2 = await LB.until((s) => s.status === 'over');
  assert.deepEqual(s2.result, { winner: null, reason: 'agreement' });

  // ván mới: đổi bên
  await post('act', { token: tok('A'), room: a.room, act: 'rematch' });
  await post('act', { token: tok('B'), room: a.room, act: 'rematch' });
  const s3 = await LA.until((s) => s.status === 'playing' && s.moves.length === 0);
  assert.equal(s3.you === 1 ? 'r' : 'b', a.side === 'r' ? 'b' : 'r', 'A đổi bên');
  // đầu hàng
  await post('act', { token: tok('A'), room: a.room, act: 'resign' });
  const s4 = await LB.until((s) => s.status === 'over');
  assert.equal(s4.result.reason, 'resign');
  assert.equal(s4.result.winner, s3.you === 1 ? 'b' : 'r');

  // phòng mời: tạo, nhập mã (chữ thường vẫn được), vào lại bằng token cũ
  const c = await post('new', { token: tok('C'), name: 'Cường', tc: '3+2', side: 'r' });
  assert.equal(c.side, 'r');
  const d = await post('join', { token: tok('D'), room: c.room.toLowerCase() });
  assert.equal(d.side, 'b');
  const again = await post('join', { token: tok('C'), room: c.room });
  assert.equal(again.side, 'r', 'vào lại đúng ghế');
  const third = await post('join', { token: tok('E'), room: c.room });
  assert.equal(third.side, null, 'người thứ ba chỉ xem');
  assert.equal((await post('join', { token: tok('E'), room: 'ZZZZZZ' })).st, 404);

  // chiếu bí: ván "pháo chiếu nhanh" giả lập bằng dãy nước hợp lệ dẫn tới bí
  // hết giờ: chỉnh đồng hồ trong phòng xuống 50ms
  const room = online._rooms.get(c.room);
  const LC = listen(c.room, tok('C'));
  room.clock[1] = 50; room.turnStart = Date.now(); room.armFlag();
  const s5 = await LC.until((s) => s.status === 'over');
  assert.deepEqual(s5.result, { winner: 'b', reason: 'time' });

  // rời phòng chờ thì phòng bị đóng
  const e = await post('new', { token: tok('F'), tc: '10+5' });
  await post('act', { token: tok('F'), room: e.room, act: 'leave' });
  assert.equal((await post('join', { token: tok('G'), room: e.room })).st, 404);
  assert.equal((await post('new', { token: 'ngắn' })).st, 400);

  for (const L of [LA, LB, LW, LC]) L.close();
  srv.close();
  console.log('online: tất cả kiểm tra đều qua');
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
