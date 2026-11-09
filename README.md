# Cờ Tướng: luyện cùng máy

Web tĩnh (HTML/CSS/JS thuần), deploy tại https://co.halle.biz qua Coolify trên `oracle-a1`.

- `site/js/engine.js`: luật, sinh nước, alpha-beta
- `site/js/worker.js`: tìm kiếm trong Web Worker
- `site/js/app.js`: giao diện, gợi ý, chấm điểm, sách khai cuộc
- `site/js/notation.js`: đọc FEN và biên bản nước đi (tiếng Việt, P2-5, WXF C2.5, chữ Hán 炮二平五) để nhập ván

Chạy thử: `cd site && python3 -m http.server 8765`

## Máy chấm Pikafish (máy chủ)
Thầy chấm nước, gợi ý, phân tích ván, đoán nước đại sư và ôn lỗi gọi `POST /api/analyse` tới
[Pikafish](https://github.com/official-pikafish/Pikafish) chạy trên máy chủ (`server/engine-server.js`, Node không cần thư viện).
Máy chủ lỗi/bận (503) hoặc không có mạng thì tự dùng engine trong trình duyệt/app; máy đối thủ và bài tập sát cục vẫn dùng engine cũ.
- `Dockerfile`: biên dịch Pikafish bản phát hành cố định (kiểm SHA-256 mã nguồn, gói phát hành, `pikafish.nnue`), nginx chuyển `/api/` sang Node (cổng 8080 nội bộ).
- Biến môi trường: `ENGINES` (số tiến trình, mặc định 2), `HASH_MB` (mặc định 64).
- Điểm Pikafish nhân 1,2 (`REMOTE_SCALE`) để giữ ngưỡng xếp loại nước đi của engine cũ.
- Giấy phép: Pikafish là GPLv3 (chạy trên máy chủ, không phân phối kèm app). File mạng `pikafish.nnue` có giấy phép riêng (`NNUE-License.md`): **không dùng cho mục đích thương mại khi chưa được phép**.
- Chạy thử cục bộ: build Pikafish (`make build ARCH=apple-silicon` trong `src/`, đặt `pikafish.nnue` cùng thư mục) rồi `PIKAFISH=/đường/dẫn/pikafish ENGINE_PORT=8081 node server/engine-server.js`.

## Bài tập sát cục
`tools/`: đào thế cờ từ ván máy tự đánh (`node mine.js <seed> <số ván>`), phân loại đòn (`classify.js`), chọn bộ bài (`select.js` → `site/js/puzzles.js`). Chạy trong thư mục `tools/`.

## Dữ liệu chuyên nghiệp (`site/data/`)
Nguồn: [chasoft/community-xiangqi-games-database](https://github.com/chasoft/community-xiangqi-games-database) (định dạng DhtmlXQ), tải về `data-src/src` (sparse clone: puzzles, end-games, selected-games, tournaments).
- `tools/dhtml.js`: đọc file DhtmlXQ, phát lại và kiểm tra nước đi.
- `tools/hanviet.js`: phiên âm Hán-Việt (tên kỳ thủ, khai cuộc ECCO, tên thế cờ).
- `node build-book.js <data/tournaments>` → `data/book.json`: sách khai cuộc từ ~104k ván giải đấu (24 nửa nước đầu).
- `node build-classics.js <id>` → `data/puzzles/<id>.json`: sát cục cổ phổ/sách sát pháp, engine kiểm chứng.
- `node dedupe-puzzles.js`: bỏ thế cờ trùng trong cùng bộ (bài giữ chỉ số gốc ở trường `k` để tiến độ đã lưu không lệch). Thế cờ có ở nhiều bộ: giải một lần là tính đã giải ở mọi bộ.
- `node build-games.js` → `data/games/`: 46 bộ ván đại sư (~8.8k ván) để xem lại và luyện đoán nước.
