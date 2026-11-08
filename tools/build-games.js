// Bước 3: đóng gói ván đại sư (selected-games) thành JSON nhỏ để xem lại / luyện đoán nước.
// node build-games.js → ../site/data/games/index.json + <id>.json
const fs = require('fs');
const path = require('path');
const D = require('./dhtml.js');
const { hv, hasUnknown } = require('./hanviet.js');
const BASE = process.env.HOME + '/Code/co-tuong-data/src/data/selected-games/';
const ECO = JSON.parse(fs.readFileSync('../site/data/book.json')).names;
const RES = { '红胜': 1, '和局': 0, '黑胜': -1 };
const slug = (s) => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

fs.mkdirSync('../site/data/games', { recursive: true });
const index = [];
for (const dir of fs.readdirSync(BASE).sort()) {
  const full = BASE + dir;
  if (!fs.statSync(full).isDirectory()) continue;
  const title = D.registerTitle(full);
  const games = [];
  for (const f of D.walk(full).sort()) {
    const g = D.parseFile(f);
    const r = D.replay(g);
    if (!r || !r.moves.length) continue;
    const n = r.bad !== undefined ? r.bad : r.moves.length;
    if (n < 10) continue;
    const it = { m: g.movelist.slice(0, n * 4) };
    if (g.binit !== D.STD_BINIT) it.fen = r.start.toFen();
    const red = hasUnknown(g.red) ? '' : hv(g.red, 'name'), black = hasUnknown(g.black) ? '' : hv(g.black, 'name');
    if (red) it.r = red; if (black) it.b = black;
    if (g.result in RES) it.res = RES[g.result];
    const em = g.open.match(/^([A-E]\d\d)/);
    if (em) it.eco = em[1] + ' · ' + (ECO[em[1]] || '');
    const t = g.title.replace(/^\d+[-.、\s]*/, '');
    if (t && !hasUnknown(t) && /[㐀-鿿]/.test(t)) it.t = hv(t);
    if (g.date && /\d{4}/.test(g.date)) it.d = g.date.match(/\d{4}/)[0];
    if (!hasUnknown(g.event) && g.event) it.ev = hv(g.event);
    // lời bình không phải chữ Hán (bộ 93 ván có bình luận tiếng Anh)
    const cm = Object.entries(g.comments).filter(([k, v]) => /^\d+$/.test(k) && v && !/[㐀-鿿]/.test(v)).map(([k, v]) => [+k, v.replace(/\s+/g, ' ').trim()]);
    if (cm.length) it.notes = cm;
    games.push(it);
  }
  if (!games.length) continue;
  const id = slug(dir).slice(0, 60);
  fs.writeFileSync('../site/data/games/' + id + '.json', JSON.stringify({ id, title, games }));
  index.push({ id, title, count: games.length, notes: games.some((x) => x.notes) });
  console.log(id, games.length);
}
fs.writeFileSync('../site/data/games/index.json', JSON.stringify(index));
console.log('collections', index.length, 'games', index.reduce((s, x) => s + x.count, 0));
