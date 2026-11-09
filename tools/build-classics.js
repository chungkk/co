// Bước 2: chọn thế sát cục từ các bộ cổ phổ / sách sát pháp, engine kiểm chứng.
// node build-classics.js <id> → ../site/data/puzzles/<id>.json
const fs = require('fs');
const D = require('./dhtml.js');
const { hv } = require('./hanviet.js');
const { themeOf } = require('./theme.js');
const { Pos, Search, MATE } = globalThis.XQ;
const BASE = require('path').join(__dirname, '../data-src/') + 'src/data/';

const COLS = {
  'sat-phap-68': { dir: 'puzzles/68-Sat-Phap-Co-Ban', title: '68 Sát pháp cơ bản', source: 'Jim Png Hau Cheng (xqinenglish.com)', named: false, maxPly: 13, cap: 80, comments: true },
  'co-ban-sat-phap': { dir: 'end-games/基本杀法', title: 'Cơ bản sát pháp', source: '基本杀法', named: false, maxPly: 9, cap: 160 },
  'sat-truoc-dai-toan': { dir: 'end-games/杀着大全', title: 'Sát trước đại toàn', source: '杀着大全', named: false, maxPly: 9, cap: 140 },
  'vu-su-ma-de': { dir: 'end-games/巫师魔题', title: 'Vu sư ma đề', source: '巫师魔题 (Xiangqi Wizard)', named: false, maxPly: 9, cap: 140 },
  'thich-tinh-nha-thu': { dir: 'end-games/Thich-Tinh-Nha-Thu', title: 'Thích Tình Nhã Thú', source: '适情雅趣 (1570, cổ phổ thời Minh)', named: true, maxPly: 11, cap: 150 },
  'mong-nhap-than-co': { dir: 'end-games/Mong-Nhap-Than-Co', title: 'Mộng Nhập Thần Cơ', source: '梦入神机 (cổ phổ thời Minh)', named: true, maxPly: 11, cap: 80 },
  'lan-kha-than-co': { dir: 'end-games/Lan-Kha-Than-Co', title: 'Lạn Kha Thần Cơ', source: '烂柯神机 (cổ phổ)', named: true, maxPly: 11, cap: 100 },
  'thao-luoc-nguyen-co': { dir: 'end-games/Thao-Luoc-Nguyen-Co-Tan-Cuc-Pho', title: 'Thao Lược Nguyên Cơ', source: '韬略元机 (cổ phổ)', named: true, maxPly: 11, cap: 80 },
  'co-pho-muon-sat': { dir: 'end-games/古谱闷杀', title: 'Cổ phổ muộn sát', source: '古谱闷杀', named: true, maxPly: 11, cap: 80 },
  'giang-ho-bach-cuc': { dir: 'end-games/江湖百局', title: 'Giang hồ bách cục', source: '江湖百局', named: true, maxPly: 11, cap: 100 },
  'khi-tu-sat-phap': { dir: 'end-games/弃子杀法', title: 'Khí tử sát pháp (thí quân)', source: '弃子杀法', named: false, maxPly: 9, cap: 100 },
  'cam-nang-dieu-thu': { dir: 'end-games/锦囊妙手', title: 'Cẩm nang diệu thủ', source: '锦囊妙手', named: false, maxPly: 9, cap: 80 },
};
function mirror(p) { const q = new Pos(); for (let s = 0; s < 90; s++) q.b[89 - s] = -p.b[s]; q.side = -p.side; q.recompute(); return q; }
const mm = (m) => (89 - (m & 127)) | ((89 - (m >> 7)) << 7);

const id = process.argv[2], cfg = COLS[id];
if (!cfg) { console.log(Object.keys(COLS).join(' ')); process.exit(0); }
const S = new Search();
const files = D.walk(BASE + cfg.dir).sort();
const items = [];
const fens = new Set(); // cùng một thế cờ có thể lặp trong sách gốc
let seen = 0, tested = 0;
for (const f of files) {
  const g = D.parseFile(f);
  const r = D.replay(g);
  if (!r || r.bad !== undefined || !r.moves.length || r.moves.length > cfg.maxPly) continue;
  if (r.pos.legalMoves().length !== 0 || r.pos.side === r.start.side) continue; // bên đi trước phải thắng
  seen++;
  let start = r.start, sol = r.moves;
  if (start.side < 0) { start = mirror(start); sol = sol.map(mm); }
  // engine kiểm chứng: tìm được chiếu bí trong đúng số nước của lời giải
  tested++;
  const v = S.run(start.clone(), { timeMs: 6000, depth: sol.length + 3, multipv: 1 });
  const b = v.multi[0];
  if (!b || b.score < MATE - sol.length) continue;
  const th = themeOf(start, sol);
  if (!th) continue;
  let name = '';
  if (cfg.named) name = hv(g.title.replace(/^.*?局\s*[-—–]?\s*/, '').replace(/^\d+[-.、\s]*/, ''));
  if (fens.has(start.toFen())) continue;
  fens.add(start.toFen());
  const it = { fen: start.toFen(), n: (sol.length + 1) / 2, sol, theme: th.theme, themes: th.themes };
  if (name && !/\?/.test(name)) it.name = name;
  if (cfg.comments) {
    const cm = Object.entries(g.comments).filter(([k, t]) => +k > 0 && t && !/[㐀-鿿]/.test(t)).map(([k, t]) => [+k, t.replace(/\s+/g, ' ').trim()]);
    if (cm.length) it.notes = cm;
  }
  items.push(it);
}
// trộn độ khó, giới hạn số bài
items.sort((a, b) => a.n - b.n);
let out = items;
if (items.length > cfg.cap) {
  const step = items.length / cfg.cap;
  out = []; for (let i = 0; i < cfg.cap; i++) out.push(items[Math.floor(i * step)]);
}
fs.mkdirSync('../site/data/puzzles', { recursive: true });
fs.writeFileSync('../site/data/puzzles/' + id + '.json', JSON.stringify({ id, title: cfg.title, source: cfg.source, items: out }));
console.log(id, 'files', files.length, 'mates', seen, 'tested', tested, 'verified', items.length, 'kept', out.length);
