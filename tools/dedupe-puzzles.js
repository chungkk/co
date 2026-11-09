// Bỏ thế cờ trùng lặp trong cùng một bộ bài tập (site/data/puzzles/*.json).
// Bài còn lại giữ chỉ số gốc ở trường "k" để tiến độ đã lưu ("bộ:số thứ tự") không bị lệch.
// Bộ "68 Sát pháp" giữ nguyên như bản đã phát hành.
// node dedupe-puzzles.js
const fs = require('fs');
const path = require('path');
const DIR = path.join(__dirname, '../site/data/puzzles/');
const KEEP = new Set(['sat-phap-68']);

const index = JSON.parse(fs.readFileSync(DIR + 'index.json', 'utf8'));
for (const c of index) {
  if (KEEP.has(c.id)) continue;
  const file = DIR + c.id + '.json';
  const d = JSON.parse(fs.readFileSync(file, 'utf8'));
  const seen = new Set(), out = [];
  d.items.forEach((it, i) => {
    if (seen.has(it.fen)) return;
    seen.add(it.fen);
    out.push(it.k === undefined ? { ...it, k: i } : it);
  });
  const removed = d.items.length - out.length;
  if (!removed) continue;
  d.items = out;
  c.count = out.length;
  fs.writeFileSync(file, JSON.stringify(d));
  console.log(c.id, 'bỏ', removed, 'bài trùng, còn', out.length);
}
fs.writeFileSync(DIR + 'index.json', JSON.stringify(index));
