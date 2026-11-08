// Đọc file DhtmlXQ (định dạng của dpxq.com / vietcotuong.com) và chuyển sang Pos của engine.
const fs = require('fs');
const path = require('path');
require('../site/js/engine.js');
const { Pos, K, A, B, N, R, C, P } = globalThis.XQ;

// Thứ tự 32 quân trong binit: Đỏ rồi Đen, mỗi bên: Xe Mã Tượng Sĩ Tướng Sĩ Tượng Mã Xe Pháo Pháo Tốt×5
const ORDER = [R, N, B, A, K, A, B, N, R, C, C, P, P, P, P, P];
const STD_BINIT = '0919293949596979891777062646668600102030405060708012720323436383';

function tag(txt, name) {
  const m = txt.match(new RegExp('\\[DhtmlXQ_' + name + '\\]([\\s\\S]*?)\\[/DhtmlXQ_' + name + '\\]'));
  return m ? m[1].trim() : '';
}
function parseFile(file) {
  let txt = fs.readFileSync(file, 'utf8');
  if (txt.charCodeAt(0) === 0xfeff) txt = txt.slice(1);
  const comments = {};
  const re = /\[DhtmlXQ_comment(\d+)\]([\s\S]*?)\[\/DhtmlXQ_comment\1\]/g;
  let m;
  while ((m = re.exec(txt))) comments[+m[1]] = m[2].replace(/\|\|/g, '\n').trim();
  return {
    file, title: tag(txt, 'title'), event: tag(txt, 'event'), date: tag(txt, 'date'), place: tag(txt, 'place'),
    red: tag(txt, 'red'), black: tag(txt, 'black'), result: tag(txt, 'result'), open: tag(txt, 'open'),
    author: tag(txt, 'author'), owner: tag(txt, 'owner'), remark: tag(txt, 'remark'),
    binit: tag(txt, 'binit') || STD_BINIT, movelist: tag(txt, 'movelist').replace(/\s/g, ''), comments,
  };
}
// binit → Pos (bên đi trước được xác định từ quân của nước đầu tiên)
function posFromBinit(binit, firstMove) {
  const p = new Pos();
  if (!/^\d{64}$/.test(binit)) return null;
  for (let i = 0; i < 32; i++) {
    const s = binit.substr(i * 2, 2);
    if (s === '99') continue;
    const x = +s[0], y = +s[1];
    if (x > 8 || y > 9) return null;
    const sq = y * 9 + x;
    if (p.b[sq]) return null;
    p.b[sq] = (i < 16 ? 1 : -1) * ORDER[i % 16];
  }
  p.side = 1;
  if (firstMove) {
    const pc = p.b[(+firstMove[1]) * 9 + (+firstMove[0])];
    if (pc < 0) p.side = -1;
  }
  p.recompute();
  if (p.kR < 0 || p.kB < 0) return null;
  return p;
}
const decodeMove = (s) => ((+s[1]) * 9 + (+s[0])) | (((+s[3]) * 9 + (+s[2])) << 7);
// Phát lại toàn bộ ván, kiểm tra hợp lệ. Trả về {start, moves} hoặc null
function replay(g, maxPly) {
  const ml = g.movelist;
  if (ml.length % 4) return null;
  const start = posFromBinit(g.binit, ml.slice(0, 4));
  if (!start) return null;
  const p = start.clone(), moves = [];
  const n = Math.min(ml.length / 4, maxPly || 1e9);
  for (let i = 0; i < n; i++) {
    const m = decodeMove(ml.substr(i * 4, 4));
    if (!p.legalMoves().includes(m)) return { start, moves, pos: p, bad: i };
    p.make(m); moves.push(m);
  }
  return { start, moves, pos: p };
}
function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const f = path.join(dir, e.name);
    if (e.isDirectory()) walk(f, out);
    else if (!e.name.endsWith('.json') && !e.name.endsWith('.md') && !e.name.endsWith('.png')) out.push(f);
  }
  return out;
}
function registerTitle(dir) {
  try { return JSON.parse(fs.readFileSync(path.join(dir, 'register.json'), 'utf8')).meta.title; } catch (e) { return path.basename(dir); }
}
module.exports = { parseFile, posFromBinit, decodeMove, replay, walk, registerTitle, STD_BINIT };
