// Tiện ích phân tích và giải thích nước đi bằng lời (port từ app.js).
import 'dart:math' as math;

import '../engine/engine.dart';

int sgn(int p) => p > 0 ? 1 : -1;
int absT(int p) => p > 0 ? p : -p;
int pval(int p) => absT(p) == K ? 10000 : VAL[absT(p)];
String nameOf(int p) => PIECE_NAME[absT(p)];
String sideName(int s) => s == RED ? 'Đỏ' : 'Đen';
int rowOf(int sq) => sq ~/ 9;
int colOf(int sq) => sq % 9;
int relRow(int sq, int s) => s > 0 ? rowOf(sq) : 9 - rowOf(sq);
int clampS(int s) => s.clamp(-2500, 2500);
String lc(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// Các quân của [side] có thể ăn ô [sq] (bỏ qua ghim)
List<int> attackers(Pos pos, int sq, int side) {
  final b = pos.b, saved = b[sq];
  b[sq] = -side * P; // đặt tạm quân đối phương để sinh nước ăn
  final out = <int>[];
  for (final m in pos.gen(true, side)) {
    if ((m >> 7) == sq) out.add(m & 127);
  }
  b[sq] = saved;
  return out;
}

bool isHanging(Pos pos, int sq) {
  final p = pos.b[sq];
  if (p == 0 || absT(p) == K) return false;
  final s = sgn(p), att = attackers(pos, sq, -s);
  if (att.isEmpty) return false;
  final def = attackers(pos, sq, s);
  if (def.isEmpty) return true;
  final minAtt = att.map((f) => pval(pos.b[f])).reduce(math.min);
  return minAtt < pval(p);
}

List<int> hangingSet(Pos pos, int side) {
  final out = <int>[];
  for (var sq = 0; sq < 90; sq++) {
    final p = pos.b[sq];
    if (p != 0 && sgn(p) == side && isHanging(pos, sq)) out.add(sq);
  }
  return out;
}

String listNames(Pos pos, List<int> sqs) {
  final ns = sqs.map((s) => nameOf(pos.b[s])).toList();
  return ns.length <= 1 ? ns.join('') : '${ns.sublist(0, ns.length - 1).join(', ')} và ${ns.last}';
}

String fmtScore(int s) {
  if (s > MATE - 500) return 'Chiếu bí sau ${((MATE - s) / 2).ceil()} nước';
  if (s < -MATE + 500) return 'Bị chiếu bí sau ${((MATE + s) / 2).ceil()} nước';
  final v = s / 100;
  return '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';
}

String pct(double x) => '${(x * 100).round()}%';

String fmtInt(int n) {
  final s = n.toString();
  final sb = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) sb.write('.');
    sb.write(s[i]);
  }
  return sb.toString();
}

/// Giải thích một nước đi bằng lời
List<String> explain(Pos pos, int m, {int? score, bool short = false}) {
  final out = <String>[];
  final f = m & 127, t = m >> 7, p = pos.b[f], q = pos.b[t], me = sgn(p);
  final after = pos.clone()..make(m);
  final oppLegal = after.legalMoves().length;
  final check = after.inCheck(after.side);
  if (oppLegal == 0) return ['Chiếu bí, kết thúc ván cờ!'];
  if (score != null && score > MATE - 500) {
    out.add('Có đường chiếu bí: thắng sau ${((MATE - score) / 2).ceil()} nước nếu đi chính xác.');
  }
  if (q != 0) {
    final recap = attackers(after, t, -me).isNotEmpty;
    if (!recap) {
      out.add('Ăn ${nameOf(q)} không mất gì: đối phương không ăn lại được.');
    } else if (pval(q) > pval(p)) {
      out.add('Ăn ${nameOf(q)} bằng ${nameOf(p)}, lời quân dù bị ăn lại.');
    } else if (pval(q) == pval(p)) {
      out.add('Đổi ${nameOf(p)} lấy ${nameOf(q)}.');
    } else {
      out.add('Ăn ${nameOf(q)}.');
    }
  }
  if (check) out.add('Chiếu Tướng, buộc đối phương phải đỡ.');
  if (short) return out.isNotEmpty ? out : [positional(pos, m)];
  final oppBefore = hangingSet(pos, -me), oppAfter = hangingSet(after, -me);
  final newT = oppAfter.where((s) => !oppBefore.contains(s)).toList();
  if (newT.length >= 2) {
    out.add('Bắt đôi: cùng lúc dọa ăn ${listNames(after, newT)}.');
  } else if (newT.length == 1) {
    out.add('Dọa ăn ${nameOf(after.b[newT[0]])}.');
  }
  final myBefore = hangingSet(pos, me), myAfter = hangingSet(after, me);
  if (myBefore.contains(f) && !myAfter.contains(t)) out.add('Đưa ${nameOf(p)} ra khỏi chỗ bị đe dọa.');
  final saved = myBefore.where((s) => s != f && after.b[s] == pos.b[s] && !myAfter.contains(s)).toList();
  if (saved.isNotEmpty) out.add('Bảo vệ ${listNames(pos, saved)} đang bị đe dọa.');
  if (out.length < 2) out.add(positional(pos, m));
  return out;
}

String positional(Pos pos, int m) {
  final f = m & 127, t = m >> 7, p = pos.b[f], me = sgn(p), tp = absT(p);
  final fr = relRow(f, me), tr = relRow(t, me), tc = colOf(t);
  bool ownPawnOnFile() {
    for (var r = 0; r < 10; r++) {
      if (pos.b[r * 9 + tc] == me * P) return true;
    }
    return false;
  }

  switch (tp) {
    case R:
      if (fr == 9 && (colOf(f) == 0 || colOf(f) == 8)) return 'Ra Xe sớm: Xe mạnh nhất bàn cờ, đừng để Xe nằm im ở góc.';
      if (tr <= 4 && fr > 4) return 'Xe qua sông, uy hiếp hậu phương đối phương.';
      if (!ownPawnOnFile()) return 'Đưa Xe vào đường mở để kiểm soát cả cột.';
      return 'Đưa Xe tới vị trí hoạt động hơn.';
    case N:
      if (fr == 9) return 'Phát triển Mã ra trận, đồng thời bảo vệ Tốt.';
      if (tr <= 4) return 'Mã tiến sang phía đối phương, chuẩn bị tấn công.';
      return 'Điều Mã tới vị trí tốt hơn (chú ý đừng để bị cản chân mã).';
    case C:
      if (tc == 4 && colOf(f) != 4) return 'Pháo đầu: nhắm thẳng vào trung lộ và Tướng đối phương.';
      return 'Đưa Pháo tới vị trí hoạt động hơn, tìm "ngòi" để tấn công.';
    case P:
      if (tr == 4 && fr == 5) return 'Tốt qua sông: từ giờ được đi ngang, trở thành mối đe dọa.';
      if (fr >= 5 && (tc == 2 || tc == 6)) return 'Tiến Tốt mở đường cho Mã.';
      return 'Tiến Tốt, tăng sức ép.';
    case A:
    case B:
      return 'Củng cố phòng thủ quanh Tướng.';
    case K:
      return 'Đưa Tướng tránh khỏi đường bị tấn công.';
  }
  return 'Cải thiện thế cờ.';
}

/// Thời gian quân trượt trên bàn (ms), tỷ lệ với quãng đường. Dùng chung cho
/// hiệu ứng bàn cờ và thời điểm phát tiếng quân chạm bàn.
int moveAnimMs(int m) {
  final f = m & 127, t = m >> 7;
  final dr = (f ~/ 9 - t ~/ 9).abs(), dc = (f % 9 - t % 9).abs();
  return (190 + 38 * math.sqrt(dr * dr + dc * dc)).clamp(210, 420).round();
}
