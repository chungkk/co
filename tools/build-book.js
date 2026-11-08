// Bước 1: dựng sách khai cuộc từ ván giải đấu chuyên nghiệp.
// node build-book.js <thư mục tournaments> → ../site/data/book.json + ecco-names.json (tên tiếng Trung, để dịch)
const fs = require('fs');
const D = require('./dhtml.js');
const root = process.argv[2];
const MAXPLY = 24, MIN_POS = 12, MIN_MOVE = 2;
const key = (p) => (p.h1 >>> 0).toString(36) + '.' + (p.h2 >>> 0).toString(36);
const RES = { '红胜': 1, '和局': 0, '黑胜': -1 };

const book = new Map(); // key -> {n, moves: Map(m -> [n,w,d,l]), eco: Map(code->n)}
const ecoNames = {};
let games = 0, used = 0;
const files = D.walk(root);
for (const f of files) {
  games++;
  const g = D.parseFile(f);
  if (g.binit !== D.STD_BINIT || !(g.result in RES)) continue;
  const r = D.replay(g, MAXPLY);
  if (!r || r.bad !== undefined) continue;
  used++;
  const res = RES[g.result];
  const em = g.open.match(/^([A-E]\d\d)\s*(.*)$/);
  if (em) { ecoNames[em[1]] = ecoNames[em[1]] || {}; ecoNames[em[1]][em[2]] = (ecoNames[em[1]][em[2]] || 0) + 1; }
  const p = r.start.clone();
  for (const m of r.moves) {
    const k = key(p);
    let e = book.get(k);
    if (!e) { e = { n: 0, moves: new Map(), eco: new Map() }; book.set(k, e); }
    e.n++;
    let s = e.moves.get(m);
    if (!s) { s = [0, 0, 0, 0]; e.moves.set(m, s); }
    const rr = res * p.side; // kết quả theo góc nhìn bên đi
    s[0]++; s[rr > 0 ? 1 : rr === 0 ? 2 : 3]++;
    if (em) e.eco.set(em[1], (e.eco.get(em[1]) || 0) + 1);
    p.make(m);
  }
}
const out = {}, eco = {};
let npos = 0;
for (const [k, e] of book) {
  if (e.n < MIN_POS) continue;
  const mv = [...e.moves].filter(([, s]) => s[0] >= MIN_MOVE && s[0] / e.n >= 0.01).sort((a, b) => b[1][0] - a[1][0]);
  if (!mv.length) continue;
  out[k] = mv.map(([m, s]) => [m, ...s]);
  npos++;
  // mã ECCO trội (≥70% số ván qua thế này)
  let best = null; for (const [c, n] of e.eco) if (!best || n > best[1]) best = [c, n];
  if (best && best[1] / e.n >= 0.7) eco[k] = best[0];
}
const names = {};
for (const [c, m] of Object.entries(ecoNames)) names[c] = Object.entries(m).sort((a, b) => b[1] - a[1])[0][0];
fs.mkdirSync('../site/data', { recursive: true });
fs.writeFileSync('../site/data/book.json', JSON.stringify({ games: used, pos: out, eco }));
fs.writeFileSync('ecco-names.zh.json', JSON.stringify(names, null, 1));
console.log('files', games, 'used', used, 'positions', npos, 'eco-tagged', Object.keys(eco).length, 'codes', Object.keys(names).length);
