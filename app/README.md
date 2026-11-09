# Cờ Tướng (iOS, Flutter)

Bản iOS native của trang web trong `site/`: đấu với máy có thầy chấm từng nước, bài tập sát cục, ván đại sư (xem lại và luyện đoán nước). Chạy hoàn toàn offline, không cần mạng.

## Cấu trúc
- `lib/engine/engine.dart`: port 1-1 của `site/js/engine.js` (luật, alpha-beta). Hash Zobrist khớp bản JS từng bit nên dùng chung `book.json`.
- `lib/engine/engine_service.dart`: chạy tìm kiếm trong Isolate (tương đương Web Worker).
- `lib/game/`: luồng 3 chế độ, phân tích và giải thích nước đi (port từ `site/js/app.js`).
- `lib/ui/`: bàn cờ, các thẻ, chủ đề sáng/tối. iPhone 1 cột, iPad 2 cột.
- `assets/data/`: bản sao `site/data/` + `puzzles/thuc-chien.json` (sinh từ `site/js/puzzles.js`).

Khi dữ liệu web thay đổi, chép lại:
```
cp -R ../site/data/* assets/data/
python3 -c "import json;s=open('../site/js/puzzles.js').read();json.dump(json.loads(s[s.index('['):s.rindex(']')+1]),open('assets/data/puzzles/thuc-chien.json','w'),ensure_ascii=False,separators=(',',':'))"
```

## Chạy
```
flutter test                      # engine khớp bản JS + luồng 3 chế độ
flutter run                       # simulator hoặc iPhone đang cắm
flutter build ipa                 # bản phát hành (cần chọn Team ký trong Xcode)
```
Lần đầu chạy trên máy thật: mở `ios/Runner.xcworkspace`, Runner → Signing & Capabilities → chọn Team. Bundle ID: `biz.halle.coTuong`.

Chụp màn hình từng chế độ: `flutter build ios --simulator --dart-define=START_MODE=puzzle` (hoặc `games`).
