// Chơi online không cần tài khoản: phòng chơi trong bộ nhớ, máy chủ kiểm tra luật và đồng hồ.
// Mỗi máy khách tự giữ một mã bí mật (token) để vào lại ván; tên hiển thị tự chọn.
// Máy khách nhận trạng thái qua Server-Sent Events (GET /api/online/events) và gửi thao tác bằng POST.
'use strict';
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

// luật cờ dùng chung với bản web (site/js/engine.js; trong Docker chép vào cạnh file này)
for (const f of [path.join(__dirname, 'engine.js'), path.join(__dirname, '../site/js/engine.js')]) {
  if (fs.existsSync(f)) { require(f); break; }
}
const { Pos, RED, BLACK } = globalThis.XQ;

// thời gian: [phút gốc, giây cộng mỗi nước]
const TC = { '3+2': [3, 2], '5+3': [5, 3], '10+5': [10, 5], '15+10': [15, 10], '30+0': [30, 0] };
const DEFAULT_TC = '10+5';
const MAX_ROOMS = 3000;
const MAX_PLY = 300;
const WAIT_TTL = 30 * 60e3; // phòng chờ không ai vào
const IDLE_TTL = 15 * 60e3; // ván đã xong, không còn ai kết nối
const LEAVE_QUICK_MS = 20e3; // người chờ ghép ngẫu nhiên đã rời đi

const rooms = new Map();
const quick = new Map(); // tc → mã phòng đang chờ ghép ngẫu nhiên
const createLog = new Map(); // ip → [thời điểm tạo phòng]

const now = () => Date.now();
const sideKey = (s) => (s === RED ? 'r' : 'b');
const newId = () => {
  // 6 ký tự dễ đọc, không lẫn 0/O, 1/I
  const A = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  for (;;) {
    let s = '';
    for (const b of crypto.randomBytes(6)) s += A[b % A.length];
    if (!rooms.has(s)) return s;
  }
};
const cleanName = (n) => {
  const s = String(n || '').replace(/[\u0000-\u001f\u007f<>]/g, '').replace(/\s+/g, ' ').trim().slice(0, 20);
  return s || 'Khách ' + (1000 + crypto.randomInt(9000));
};
const validToken = (t) => typeof t === 'string' && /^[A-Za-z0-9_-]{16,64}$/.test(t);

class Room {
  constructor(tc, isQuick) {
    this.id = newId();
    this.tc = TC[tc] ? tc : DEFAULT_TC;
    this.quick = !!isQuick;
    this.created = this.last = now();
    this.status = 'waiting'; // waiting | playing | over
    this.seats = { [RED]: null, [BLACK]: null }; // { token, name }
    this.conns = new Set(); // { res, token }: bên của kết nối tính lại từ token (đổi bên khi chơi ván mới)
    this.reset();
    rooms.set(this.id, this);
  }
  reset() {
    this.pos = Pos.start();
    this.moves = [];
    const [m, inc] = TC[this.tc];
    this.base = m * 60e3; this.inc = inc * 1e3;
    this.clock = { [RED]: this.base, [BLACK]: this.base };
    this.turnStart = 0;
    this.result = null;
    this.drawOffer = 0;
    this.rematch = { [RED]: false, [BLACK]: false };
    clearTimeout(this.flagTimer);
  }
  sideOf(token) {
    if (!validToken(token)) return 0;
    for (const s of [RED, BLACK]) if (this.seats[s] && this.seats[s].token === token) return s;
    return 0;
  }
  online(s) { for (const c of this.conns) if (this.sideOf(c.token) === s) return true; return false; }
  start() {
    this.status = 'playing';
    this.turnStart = now();
    this.armFlag();
  }
  armFlag() {
    clearTimeout(this.flagTimer);
    if (this.status !== 'playing') return;
    const s = this.pos.side, left = this.clock[s] - (now() - this.turnStart);
    this.flagTimer = setTimeout(() => this.checkFlag(), Math.max(0, left) + 50);
  }
  checkFlag() {
    if (this.status !== 'playing') return;
    const s = this.pos.side;
    if (this.clock[s] - (now() - this.turnStart) <= 0) {
      this.clock[s] = 0;
      this.finish(-s, 'time');
    } else this.armFlag();
  }
  finish(winner, reason) {
    if (this.status === 'playing') {
      const s = this.pos.side;
      this.clock[s] = Math.max(0, this.clock[s] - (now() - this.turnStart));
    }
    this.status = 'over';
    this.result = { winner, reason };
    this.drawOffer = 0;
    clearTimeout(this.flagTimer);
    this.last = now();
    this.broadcast();
  }
  move(side, m, ply) {
    if (this.status !== 'playing') return 'Ván chưa bắt đầu hoặc đã kết thúc.';
    if (this.pos.side !== side) return 'Chưa đến lượt bạn.';
    if (ply !== this.moves.length) return 'Thế cờ đã thay đổi, hãy tải lại.';
    if (!Number.isInteger(m) || !this.pos.isLegal(m)) return 'Nước đi không hợp lệ.';
    const t = now(), used = t - this.turnStart;
    if (this.clock[side] - used <= 0) { this.clock[side] = 0; this.finish(-side, 'time'); return 'Hết giờ.'; }
    this.clock[side] += this.inc - used;
    this.pos.make(m);
    this.moves.push(m);
    this.turnStart = t;
    this.last = t;
    this.drawOffer = 0;
    if (this.pos.legalMoves().length === 0) this.finish(side, this.pos.inCheck(this.pos.side) ? 'mate' : 'stalemate');
    else if (this.pos.repCount() >= 3) this.finish(0, 'repetition');
    else if (this.moves.length >= MAX_PLY) this.finish(0, 'length');
    else { this.armFlag(); this.broadcast(); }
    return null;
  }
  state(side) {
    const t = now(), running = this.status === 'playing' ? this.pos.side : 0;
    const clk = (s) => Math.max(0, this.clock[s] - (s === running ? t - this.turnStart : 0));
    const seat = (s) => (this.seats[s] ? this.seats[s].name : null);
    return {
      room: this.id, status: this.status, tc: this.tc, quick: this.quick,
      you: side || null,
      names: { r: seat(RED), b: seat(BLACK) },
      online: { r: this.online(RED), b: this.online(BLACK) },
      moves: this.moves,
      clock: { r: clk(RED), b: clk(BLACK) }, running: running ? sideKey(running) : null,
      result: this.result && { winner: this.result.winner ? sideKey(this.result.winner) : null, reason: this.result.reason },
      drawOffer: this.drawOffer ? sideKey(this.drawOffer) : null,
      rematch: { r: this.rematch[RED], b: this.rematch[BLACK] },
      watchers: [...this.conns].filter((c) => !this.sideOf(c.token)).length,
    };
  }
  broadcast() {
    for (const c of this.conns) sse(c.res, this.state(this.sideOf(c.token)));
  }
}

function sse(res, data) {
  try { res.write('data: ' + JSON.stringify(data) + '\n\n'); } catch (e) { /* kết nối đã đóng */ }
}

function allowCreate(ip) {
  const t = now(), arr = (createLog.get(ip) || []).filter((x) => t - x < 10 * 60e3);
  if (arr.length >= 30) return false;
  arr.push(t); createLog.set(ip, arr);
  return true;
}

// ---------- các thao tác ----------
function create(q, ip) {
  if (rooms.size >= MAX_ROOMS) return [503, { error: 'Máy chủ đang quá tải, hãy thử lại sau.' }];
  if (!allowCreate(ip)) return [429, { error: 'Tạo phòng quá nhiều, hãy đợi một lát.' }];
  const r = new Room(q.tc, false);
  const side = q.side === 'r' ? RED : q.side === 'b' ? BLACK : crypto.randomInt(2) ? RED : BLACK;
  r.seats[side] = { token: q.token, name: cleanName(q.name) };
  return [200, { room: r.id, side: sideKey(side) }];
}

function join(q) {
  const r = rooms.get(String(q.room || '').toUpperCase());
  if (!r) return [404, { error: 'Không tìm thấy phòng. Mã phòng sai hoặc phòng đã hết hạn.' }];
  let side = r.sideOf(q.token);
  if (!side && r.status === 'waiting') {
    side = r.seats[RED] ? BLACK : RED;
    r.seats[side] = { token: q.token, name: cleanName(q.name) };
    if (r.quick && quick.get(r.tc) === r.id) quick.delete(r.tc);
    r.start();
    r.broadcast();
  }
  return [200, { room: r.id, side: side ? sideKey(side) : null }];
}

function quickMatch(q, ip) {
  const tc = TC[q.tc] ? q.tc : DEFAULT_TC;
  const id = quick.get(tc), w = id && rooms.get(id);
  if (w && w.status === 'waiting' && !w.sideOf(q.token)) return join({ room: w.id, token: q.token, name: q.name });
  if (w && w.sideOf(q.token)) return [200, { room: w.id, side: sideKey(w.sideOf(q.token)) }];
  if (rooms.size >= MAX_ROOMS) return [503, { error: 'Máy chủ đang quá tải, hãy thử lại sau.' }];
  if (!allowCreate(ip)) return [429, { error: 'Tạo phòng quá nhiều, hãy đợi một lát.' }];
  const r = new Room(tc, true);
  const side = crypto.randomInt(2) ? RED : BLACK;
  r.seats[side] = { token: q.token, name: cleanName(q.name) };
  quick.set(tc, r.id);
  return [200, { room: r.id, side: sideKey(side) }];
}

function act(q) {
  const r = rooms.get(String(q.room || '').toUpperCase());
  if (!r) return [404, { error: 'Không tìm thấy phòng.' }];
  const s = r.sideOf(q.token);
  if (!s) return [403, { error: 'Bạn không phải người chơi trong phòng này.' }];
  r.last = now();
  switch (q.act) {
    case 'move': {
      const err = r.move(s, q.move, q.ply);
      return err ? [409, { error: err, state: r.state(s) }] : [200, { ok: true }];
    }
    case 'resign':
      if (r.status !== 'playing') return [409, { error: 'Ván không diễn ra.' }];
      r.finish(-s, 'resign');
      break;
    case 'draw':
      if (r.status !== 'playing') return [409, { error: 'Ván không diễn ra.' }];
      if (r.drawOffer === -s) r.finish(0, 'agreement');
      else { r.drawOffer = s; r.broadcast(); }
      break;
    case 'accept':
      if (r.status === 'playing' && r.drawOffer === -s) r.finish(0, 'agreement');
      break;
    case 'decline':
      if (r.drawOffer === -s) { r.drawOffer = 0; r.broadcast(); }
      break;
    case 'rematch':
      if (r.status !== 'over') return [409, { error: 'Ván chưa kết thúc.' }];
      r.rematch[s] = true;
      if (r.rematch[RED] && r.rematch[BLACK]) {
        // ván mới: đổi bên
        const a = r.seats[RED]; r.seats[RED] = r.seats[BLACK]; r.seats[BLACK] = a;
        r.reset(); r.start();
      }
      r.broadcast();
      break;
    case 'leave':
      if (r.status === 'waiting') { closeRoom(r); return [200, { ok: true }]; }
      if (r.status === 'playing') r.finish(-s, 'resign');
      break;
    default:
      return [400, { error: 'Thao tác không hợp lệ.' }];
  }
  return [200, { ok: true }];
}

function closeRoom(r) {
  clearTimeout(r.flagTimer);
  if (quick.get(r.tc) === r.id) quick.delete(r.tc);
  for (const c of r.conns) { sse(c.res, { room: r.id, status: 'closed' }); try { c.res.end(); } catch (e) { /* đã đóng */ } }
  rooms.delete(r.id);
}

function events(req, res, u) {
  const r = rooms.get(String(u.searchParams.get('room') || '').toUpperCase());
  if (!r) { res.writeHead(404, { 'Content-Type': 'application/json' }); return res.end(JSON.stringify({ error: 'Không tìm thấy phòng.' })); }
  const token = u.searchParams.get('token') || '';
  res.writeHead(200, { 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-store', 'X-Accel-Buffering': 'no', Connection: 'keep-alive' });
  res.write('retry: 2000\n\n');
  const c = { res, token };
  r.conns.add(c);
  r.broadcast();
  req.on('close', () => { r.conns.delete(c); r.last = now(); if (rooms.has(r.id)) r.broadcast(); });
}

// giữ kết nối SSE qua proxy và dọn phòng cũ
setInterval(() => {
  const t = now();
  for (const r of rooms.values()) {
    for (const c of r.conns) { try { c.res.write(': ping\n\n'); } catch (e) { /* đã đóng */ } }
    const idle = r.conns.size === 0;
    if (r.status === 'waiting' && (t - r.created > WAIT_TTL || (r.quick && idle && t - r.last > LEAVE_QUICK_MS))) closeRoom(r);
    else if (r.status === 'over' && idle && t - r.last > IDLE_TTL) closeRoom(r);
  }
  for (const [ip, arr] of createLog) if (!arr.some((x) => t - x < 10 * 60e3)) createLog.delete(ip);
}, 20e3).unref();

function readJson(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (d) => { body += d; if (body.length > 2000) req.destroy(); });
    req.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { resolve(null); } });
  });
}

/** Xử lý /api/online/*; trả về false nếu không phải đường dẫn của module này. */
function handle(req, res, ip, send) {
  const u = new URL(req.url, 'http://x');
  if (!u.pathname.startsWith('/api/online/')) return false;
  const p = u.pathname.slice('/api/online/'.length);
  if (p === 'events' && req.method === 'GET') { events(req, res, u); return true; }
  if (p === 'stats' && req.method === 'GET') {
    let playing = 0; for (const r of rooms.values()) if (r.status === 'playing') playing++;
    send(res, 200, { rooms: rooms.size, playing, waiting: [...quick.keys()] });
    return true;
  }
  if (req.method !== 'POST') { send(res, 404, { error: 'not found' }); return true; }
  readJson(req).then((q) => {
    if (!q || !validToken(q.token)) return send(res, 400, { error: 'Yêu cầu không hợp lệ.' });
    const [st, body] = p === 'new' ? create(q, ip) : p === 'join' ? join(q) : p === 'quick' ? quickMatch(q, ip) : p === 'act' ? act(q) : [404, { error: 'not found' }];
    send(res, st, body);
  });
  return true;
}

module.exports = { handle, TC, _rooms: rooms };
