// Chơi online không cần tài khoản (máy chủ: server/online.js).
// Máy này giữ một mã bí mật (token) để vào lại ván khi mất kết nối; trạng thái ván nhận qua
// Server-Sent Events, thao tác gửi bằng POST.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const onlineTcs = ['3+2', '5+3', '10+5', '15+10', '30+0'];
const onlineTcLabels = {'3+2': '3 + 2 (chớp)', '5+3': '5 + 3 (nhanh)', '10+5': '10 + 5', '15+10': '15 + 10', '30+0': '30 phút'};
const onlineReason = {
  'mate': 'chiếu bí',
  'stalemate': 'hết nước đi',
  'time': 'hết giờ',
  'resign': 'đầu hàng',
  'agreement': 'hai bên thỏa thuận hòa',
  'repetition': 'lặp lại thế cờ 3 lần',
  'length': 'ván cờ quá dài',
};

String _randToken() {
  const a = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  final r = math.Random.secure();
  return List.generate(24, (_) => a[r.nextInt(a.length)]).join();
}

/// Kết nối tới máy chủ chơi online. [onState] nhận trạng thái mới; [onChange] khi cần vẽ lại.
class OnlineClient {
  /// Địa chỉ máy chủ (test có thể đổi)
  static Uri base = Uri.parse('https://co.halle.biz/api/online/');

  final void Function(Map<String, dynamic> st) onState;
  final void Function() onChange;
  final void Function(String? room) saveRoom;
  String token;
  String? room;

  /// Trạng thái ván gần nhất từ máy chủ, và thời điểm nhận (để đồng hồ chạy tiếp)
  Map<String, dynamic>? st;
  int recvAt = 0;
  bool busy = false, offline = false;
  String err = '';
  String? kind; // quick | new | join

  HttpClient? _http;
  StreamSubscription<String>? _sub;
  int _gen = 0;

  OnlineClient({
    required String? token,
    required this.room,
    required this.onState,
    required this.onChange,
    required this.saveRoom,
  }) : token = (token != null && RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(token)) ? token : _randToken();

  HttpClient get _client => _http ??= HttpClient()..connectionTimeout = const Duration(seconds: 8);

  Future<(int, Map<String, dynamic>)> post(String path, Map<String, dynamic> body) async {
    try {
      final req = await _client.postUrl(base.resolve(path)).timeout(const Duration(seconds: 10));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'token': token, ...body}));
      final res = await req.close().timeout(const Duration(seconds: 10));
      final text = await res.transform(utf8.decoder).join();
      Map<String, dynamic> d = {};
      try {
        d = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}
      return (res.statusCode, d);
    } catch (_) {
      return (0, <String, dynamic>{'error': 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'});
    }
  }

  /// Vào chơi: [kind] quick (ghép ngẫu nhiên), new (tạo phòng), join (nhập mã [code])
  Future<void> start(String kind, {required String name, required String tc, String? code}) async {
    if (busy) return;
    busy = true;
    err = '';
    onChange();
    final body = <String, dynamic>{'name': name, 'tc': tc, 'room': ?code};
    final (status, d) = await post(kind == 'quick' ? 'quick' : (kind == 'new' ? 'new' : 'join'), body);
    busy = false;
    if (status != 200) {
      err = d['error'] as String? ?? 'Có lỗi xảy ra.';
      onChange();
      return;
    }
    this.kind = kind;
    room = d['room'] as String;
    saveRoom(room);
    connect();
  }

  /// Mở luồng sự kiện của phòng; mất kết nối thì tự nối lại, phòng không còn thì báo [onGone]
  void Function(String msg)? onGone;

  void connect() {
    close();
    final r = room;
    if (r == null) return;
    final gen = ++_gen;
    () async {
      try {
        final url = base.resolve('events').replace(queryParameters: {'room': r, 'token': token});
        final req = await _client.getUrl(url).timeout(const Duration(seconds: 10));
        req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
        final res = await req.close().timeout(const Duration(seconds: 10));
        if (gen != _gen) return;
        if (res.statusCode == 404) {
          _gone('Phòng $r không còn (đã hết hạn hoặc máy chủ vừa khởi động lại).');
          return;
        }
        if (res.statusCode != 200) throw HttpException('status ${res.statusCode}');
        offline = false;
        onChange();
        var data = StringBuffer();
        _sub = res.transform(utf8.decoder).transform(const LineSplitter()).listen(
          (line) {
            if (gen != _gen) return;
            if (line.startsWith('data: ')) {
              data.write(line.substring(6));
            } else if (line.isEmpty && data.isNotEmpty) {
              final s = data.toString();
              data = StringBuffer();
              try {
                final m = jsonDecode(s) as Map<String, dynamic>;
                if (m['status'] == 'closed') {
                  _gone('Phòng đã đóng.');
                } else {
                  st = m;
                  recvAt = DateTime.now().millisecondsSinceEpoch;
                  onState(m);
                }
              } catch (_) {}
            }
          },
          onDone: () => _retry(gen),
          onError: (_) => _retry(gen),
          cancelOnError: true,
        );
      } catch (_) {
        _retry(gen);
      }
    }();
  }

  void _retry(int gen) {
    if (gen != _gen) return;
    offline = true;
    onChange();
    Future.delayed(const Duration(seconds: 2), () {
      if (gen == _gen && room != null) connect();
    });
  }

  void _gone(String msg) {
    close();
    room = null;
    st = null;
    saveRoom(null);
    err = msg;
    onGone?.call(msg);
  }

  /// Ngắt luồng sự kiện (ván vẫn tiếp tục trên máy chủ)
  void close() {
    _gen++;
    _sub?.cancel();
    _sub = null;
  }

  Future<String?> act(String act, [Map<String, dynamic> extra = const {}]) async {
    final r = room;
    if (r == null) return null;
    final (status, d) = await post('act', {'room': r, 'act': act, ...extra});
    if (status == 200) return null;
    if (d['state'] is Map<String, dynamic>) {
      st = d['state'] as Map<String, dynamic>;
      recvAt = DateTime.now().millisecondsSinceEpoch;
      onState(st!);
    }
    return d['error'] as String? ?? 'Có lỗi xảy ra.';
  }

  Future<void> leave() async {
    if (room != null) await post('act', {'room': room, 'act': 'leave'});
    _gone('');
  }

  /// Thời gian còn lại của bên [k] ('r' | 'b'), tính cả thời gian đã trôi từ lúc nhận trạng thái
  int clock(String k) {
    final s = st;
    if (s == null) return 0;
    final v = (s['clock'][k] as num).toInt();
    return s['running'] == k ? v - (DateTime.now().millisecondsSinceEpoch - recvAt) : v;
  }

  void dispose() {
    close();
    _http?.close(force: true);
  }
}

String fmtClock(int ms) {
  final t = (math.max(0, ms) / 1000).ceil();
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}
