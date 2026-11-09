import '../engine/engine.dart';

const int coachMs = 1100;

class Level {
  final String name;
  final SearchOpts opts;
  final int margin;
  final double randomChance;
  const Level(this.name, this.opts, this.margin, [this.randomChance = 0]);
}

const levels = <Level?>[
  null,
  Level('Mới tập', SearchOpts(depth: 1, multipv: 8), 160, 0.25),
  Level('Dễ', SearchOpts(depth: 2, multipv: 6), 70, 0.08),
  Level('Trung bình', SearchOpts(depth: 4, timeMs: 500, multipv: 3), 25),
  Level('Khá', SearchOpts(timeMs: 1300, multipv: 2), 8),
  Level('Giỏi', SearchOpts(timeMs: 3000, multipv: 1), 0),
];

class MoveClass {
  final String label, short, icon;
  const MoveClass(this.label, this.short, this.icon);
}

const cls = <String, MoveClass>{
  'best': MoveClass('Nước hay nhất', 'Hay nhất', '★'),
  'good': MoveClass('Nước tốt', 'Tốt', '✓'),
  'book': MoveClass('Nước của đại sư', 'Đại sư', '📖'),
  'inacc': MoveClass('Chưa chính xác', 'Chưa chuẩn', '?!'),
  'mistake': MoveClass('Sai lầm', 'Sai lầm', '?'),
  'blunder': MoveClass('Nước hỏng', 'Hỏng', '??'),
};

const accOf = {'best': 100, 'book': 100, 'good': 90, 'inacc': 65, 'mistake': 35, 'blunder': 5};

// Sách khai cuộc nhỏ: chuỗi tên nước (dự phòng khi chưa nạp được book.json)
const smallBook = [
  ['Pháo 2 bình 5', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Xe 9 bình 8', 'Xe 1 bình 2', 'Mã 2 tiến 3', 'Tốt 7 tiến 1', 'Tốt 7 tiến 1'],
  ['Pháo 2 bình 5', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Mã 2 tiến 3', 'Xe 1 bình 2', 'Xe 9 bình 8'],
  ['Pháo 2 bình 5', 'Pháo 8 bình 5', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Xe 1 bình 2', 'Xe 9 bình 8'],
  ['Pháo 2 bình 5', 'Pháo 2 bình 5', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Xe 1 bình 2', 'Xe 9 bình 8'],
  ['Pháo 2 bình 5', 'Tượng 3 tiến 5', 'Mã 2 tiến 3', 'Mã 2 tiến 3'],
  ['Pháo 8 bình 5', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Mã 8 tiến 7', 'Xe 9 bình 8', 'Xe 9 bình 8'],
  ['Tốt 7 tiến 1', 'Tốt 7 tiến 1', 'Mã 8 tiến 7', 'Mã 8 tiến 7'],
  ['Tốt 7 tiến 1', 'Pháo 2 bình 3', 'Pháo 8 bình 5', 'Tượng 3 tiến 5'],
  ['Tượng 3 tiến 5', 'Pháo 8 bình 4', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Xe 1 bình 2', 'Xe 9 bình 8'],
  ['Mã 2 tiến 3', 'Tốt 7 tiến 1', 'Tốt 7 tiến 1', 'Mã 8 tiến 7'],
  ['Pháo 2 bình 4', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Xe 9 bình 8'],
];

class Opening {
  final List<String> seq;
  final String name;
  final String? tip;
  const Opening(this.seq, this.name, this.tip);
}

const openings = [
  Opening(['Pháo 2 bình 5', 'Pháo 8 bình 5'], 'Thuận pháo', 'Hai bên cùng Pháo đầu. Tranh nhau ra Xe nhanh, chú ý trung lộ.'),
  Opening(['Pháo 8 bình 5', 'Pháo 2 bình 5'], 'Thuận pháo', 'Hai bên cùng Pháo đầu. Tranh nhau ra Xe nhanh, chú ý trung lộ.'),
  Opening(
    ['Pháo 2 bình 5', 'Pháo 2 bình 5'],
    'Nghịch pháo (Liệt pháo)',
    'Đen chơi Pháo đầu ngược cánh, thế cờ sắc bén, đối công ngay từ đầu.',
  ),
  Opening(
    ['Pháo 8 bình 5', 'Pháo 8 bình 5'],
    'Nghịch pháo (Liệt pháo)',
    'Đen chơi Pháo đầu ngược cánh, thế cờ sắc bén, đối công ngay từ đầu.',
  ),
  Opening(
    ['Pháo 2 bình 5', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Mã 2 tiến 3'],
    'Pháo đầu đối Bình phong mã',
    'Đen ra hai Mã bảo vệ Tốt đầu. Đỏ thường ra Xe, tiến Tốt 7 hoặc tấn công trung lộ.',
  ),
  Opening(
    ['Pháo 8 bình 5', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Mã 8 tiến 7'],
    'Pháo đầu đối Bình phong mã',
    'Đen ra hai Mã bảo vệ Tốt đầu. Đỏ thường ra Xe, tiến Tốt và tấn công trung lộ.',
  ),
  Opening(
    ['Pháo 2 bình 5'],
    'Pháo đầu (Trung pháo)',
    'Khai cuộc tấn công phổ biến nhất: Pháo nhắm vào Tốt đầu và Tướng. Tiếp theo nên ra Mã, ra Xe.',
  ),
  Opening(
    ['Pháo 8 bình 5'],
    'Pháo đầu (Trung pháo)',
    'Khai cuộc tấn công phổ biến nhất: Pháo nhắm vào Tốt đầu và Tướng. Tiếp theo nên ra Mã, ra Xe.',
  ),
  Opening(['Tốt 7 tiến 1'], 'Tiên nhân chỉ lộ', 'Tiến Tốt 3 hoặc 7 để mở đường cho Mã, thăm dò ý đồ đối phương.'),
  Opening(['Tốt 3 tiến 1'], 'Tiên nhân chỉ lộ', 'Tiến Tốt 3 hoặc 7 để mở đường cho Mã, thăm dò ý đồ đối phương.'),
  Opening(['Tượng 3 tiến 5'], 'Phi tượng cuộc', 'Khai cuộc phòng thủ vững chắc, phản công sau.'),
  Opening(['Tượng 7 tiến 5'], 'Phi tượng cuộc', 'Khai cuộc phòng thủ vững chắc, phản công sau.'),
  Opening(['Mã 2 tiến 3'], 'Khởi mã cuộc', 'Ra Mã trước, linh hoạt chuyển sang nhiều thế trận.'),
  Opening(['Mã 8 tiến 7'], 'Khởi mã cuộc', 'Ra Mã trước, linh hoạt chuyển sang nhiều thế trận.'),
  Opening(['Pháo 2 bình 4'], 'Sĩ giác pháo', 'Pháo đặt ở góc Sĩ, kín đáo, chuẩn bị ra Xe nhanh.'),
  Opening(['Pháo 8 bình 6'], 'Sĩ giác pháo', 'Pháo đặt ở góc Sĩ, kín đáo, chuẩn bị ra Xe nhanh.'),
  Opening(['Pháo 2 bình 6'], 'Quá cung pháo', 'Pháo đi qua cung Tướng sang cánh kia, thế trận vững.'),
  Opening(['Pháo 8 bình 4'], 'Quá cung pháo', 'Pháo đi qua cung Tướng sang cánh kia, thế trận vững.'),
];

const han = {
  1: ['帥', '將'],
  2: ['仕', '士'],
  3: ['相', '象'],
  4: ['傌', '馬'],
  5: ['俥', '車'],
  6: ['炮', '砲'],
  7: ['兵', '卒'],
};
const viet = {1: 'Tg', 2: 'S', 3: 'T', 4: 'M', 5: 'X', 6: 'P', 7: 'B'};

const themeInfo = {
  'Mã hậu pháo': 'Mã đứng trước làm ngòi cho Pháo phía sau, đồng thời khống chế các ô cạnh Tướng. Một trong những đòn sát kinh điển nhất.',
  'Trùng pháo': 'Hai Pháo xếp chồng trên một đường: Pháo trước làm ngòi cho Pháo sau. Tướng chạy dọc đường vẫn bị chiếu.',
  'Bạch diện tướng': 'Lợi dụng luật lộ mặt tướng: Tướng mình khống chế cả cột, Tướng đối phương không thể bước sang.',
  'Pháo đáy': 'Pháo xuống hàng đáy, dùng chính Sĩ/Tượng đối phương làm ngòi, Tướng bị kẹt trong cung.',
  'Song chiếu': 'Một nước tạo ra hai đường chiếu cùng lúc: không thể vừa chặn vừa ăn.',
  'Thí quân': 'Hy sinh quân để mở đường chiếu bí. Phải tính đến cùng mới dám đi!',
  'Xe Mã': 'Xe và Mã phối hợp: Mã khống chế ô thoát, Xe chiếu hết (hoặc ngược lại).',
  'Mã Pháo': 'Mã và Pháo phối hợp vây Tướng.',
  'Tốt sát': 'Tốt qua sông áp sát cung, một Tốt cũng có thể kết liễu ván cờ.',
  'Song xe': 'Hai Xe thay nhau chiếu, dồn Tướng vào đường cùng.',
  'Mã sát': 'Mã chiếu bí: chú ý chân mã và các ô Mã khống chế.',
  'Pháo mượn ngòi': 'Pháo dùng quân của đối phương làm ngòi để chiếu.',
  'Pháo sát': 'Pháo chiếu bí nhờ một quân làm ngòi.',
  'Xe sát': 'Xe chiếu hết: tìm hàng hoặc cột then chốt để Xe chiếm.',
};
