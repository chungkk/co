# Cờ Tướng: luyện cùng máy

Web tĩnh (HTML/CSS/JS thuần), deploy tại https://co.halle.biz qua Coolify trên `oracle-a1`.

- `site/js/engine.js`: luật, sinh nước, alpha-beta
- `site/js/worker.js`: tìm kiếm trong Web Worker
- `site/js/app.js`: giao diện, gợi ý, chấm điểm, sách khai cuộc

Chạy thử: `cd site && python3 -m http.server 8765`

## Bài tập sát cục
`tools/`: đào thế cờ từ ván máy tự đánh (`node mine.js <seed> <số ván>`), phân loại đòn (`classify.js`), chọn bộ bài (`select.js` → `site/js/puzzles.js`). Chạy trong thư mục `tools/`.

## Dữ liệu chuyên nghiệp (`site/data/`)
Nguồn: [chasoft/community-xiangqi-games-database](https://github.com/chasoft/community-xiangqi-games-database) (định dạng DhtmlXQ), tải về `data-src/src` (sparse clone: puzzles, end-games, selected-games, tournaments).
- `tools/dhtml.js`: đọc file DhtmlXQ, phát lại và kiểm tra nước đi.
- `tools/hanviet.js`: phiên âm Hán-Việt (tên kỳ thủ, khai cuộc ECCO, tên thế cờ).
- `node build-book.js <data/tournaments>` → `data/book.json`: sách khai cuộc từ ~104k ván giải đấu (24 nửa nước đầu).
- `node build-classics.js <id>` → `data/puzzles/<id>.json`: sát cục cổ phổ/sách sát pháp, engine kiểm chứng.
- `node build-games.js` → `data/games/`: 46 bộ ván đại sư (~8.8k ván) để xem lại và luyện đoán nước.
