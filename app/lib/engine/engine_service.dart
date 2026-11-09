// Chạy tìm kiếm trong Isolate riêng (tương đương Web Worker bên bản web), và phân tích bằng
// Pikafish trên máy chủ (server/engine-server.js) khi có mạng.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'engine.dart';

class _Req {
  final int id;
  final String fen;
  final List<List<int>> hist;
  final SearchOpts opts;
  _Req(this.id, this.fen, this.hist, this.opts);
}

class _Res {
  final int id;
  final SearchResult result;
  _Res(this.id, this.result);
}

void _worker(SendPort out) {
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  final searcher = Search();
  inbox.listen((msg) {
    final r = msg as _Req;
    final pos = Pos.fromFen(r.fen);
    pos.setHistory(r.hist);
    out.send(_Res(r.id, searcher.run(pos, r.opts)));
  });
}

/// Thang điểm Pikafish nhỏ hơn engine trong app ~20% (thiếu Mã: -310 so với -374):
/// nhân lên để giữ nguyên ngưỡng xếp loại nước đi
const remoteScale = 1.2;

int _uciSq(String u, int i) => (9 - (u.codeUnitAt(i + 1) - 48)) * 9 + (u.codeUnitAt(i) - 97);
final _uciRe = RegExp(r'^[a-i]\d[a-i]\d$');

/// Chuyển kết quả JSON của máy chủ sang [SearchResult]; bỏ nước không hợp lệ
SearchResult? fromRemote(Pos pos, Map<String, dynamic> d) {
  final multi = <PvLine>[];
  for (final x in (d['multi'] as List?) ?? const []) {
    final p = pos.clone(), pv = <int>[];
    for (final u in (x['pv'] as List?) ?? const []) {
      if (u is! String || !_uciRe.hasMatch(u)) break;
      final m = _uciSq(u, 0) | (_uciSq(u, 2) << 7);
      if (!p.isLegal(m)) break;
      pv.add(m);
      p.make(m);
    }
    if (pv.isEmpty) continue;
    final mate = (x['mate'] as num?)?.toInt();
    final score = mate != null
        ? (mate > 0 ? MATE - (2 * mate - 1) : -(MATE - 2 * -mate))
        : (((x['cp'] as num?)?.toInt() ?? 0) * remoteScale).round().clamp(-MATE + 500, MATE - 500);
    multi.add(PvLine(pv[0], score, pv));
  }
  if (multi.isEmpty) return null;
  return SearchResult(multi, [for (final x in multi) RootScore(x.move, x.score, true)], (d['depth'] as num?)?.toInt() ?? 0, 0,
      (d['ms'] as num?)?.toInt() ?? 0);
}

class EngineService {
  /// Máy chủ Pikafish; null = chỉ dùng engine trong app (test)
  static Uri? remoteUrl = Uri.parse('https://co.halle.biz/api/analyse');

  /// true: lần phân tích gần nhất dùng Pikafish; false: engine trong app; null: chưa phân tích
  bool? remoteUsed;
  int _remoteOff = 0, _remoteFails = 0, _gen = 0;
  HttpClient? _httpClient;
  HttpClient get _http => _httpClient ??= HttpClient()..connectionTimeout = const Duration(seconds: 4);

  Isolate? _iso;
  ReceivePort? _rx;
  Completer<SendPort>? _tx;
  final Map<int, Completer<SearchResult?>> _q = {};
  int _id = 0;

  EngineService() {
    _spawn();
  }

  void _spawn() {
    final rx = ReceivePort();
    final tx = Completer<SendPort>();
    _rx = rx;
    _tx = tx;
    rx.listen((msg) {
      if (msg is SendPort) {
        tx.complete(msg);
      } else if (msg is _Res) {
        _q.remove(msg.id)?.complete(msg.result);
      }
    });
    Isolate.spawn(_worker, rx.sendPort).then((iso) {
      if (_rx == rx) {
        _iso = iso;
      } else {
        iso.kill(priority: Isolate.immediate);
      }
    });
  }

  /// Trả về null nếu bị huỷ bởi [reset].
  Future<SearchResult?> search(Pos pos, SearchOpts opts) {
    final id = ++_id;
    final c = Completer<SearchResult?>();
    _q[id] = c;
    final tx = _tx!;
    final req = _Req(id, pos.toFen(), pos.historyPairs(), opts);
    tx.future.then((port) {
      if (_tx == tx && _q.containsKey(id)) port.send(req);
    });
    return c.future;
  }

  void _remoteFail() {
    if (++_remoteFails >= 3) {
      _remoteOff = DateTime.now().millisecondsSinceEpoch + 60000; // tạm nghỉ 1 phút
      _remoteFails = 0;
    }
  }

  /// Phân tích để chấm nước: Pikafish trên máy chủ (mạnh hơn nhiều); lỗi/bận/không mạng thì
  /// dùng engine trong app. Máy đối thủ và bài tập vẫn dùng [search]. Trả về null nếu bị [reset].
  Future<SearchResult?> analyse(Pos pos, SearchOpts opts) async {
    final url = remoteUrl;
    if (url != null && DateTime.now().millisecondsSinceEpoch >= _remoteOff) {
      final gen = _gen, ms = opts.timeMs ?? 1000, limit = Duration(milliseconds: ms + 4000);
      try {
        final req = await _http.postUrl(url).timeout(limit);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'fen': pos.toFen(), 'multipv': opts.multipv, 'ms': ms}));
        final res = await req.close().timeout(limit);
        final body = await res.transform(utf8.decoder).join().timeout(limit);
        if (gen != _gen) return null;
        if (res.statusCode == 200) {
          final r = fromRemote(pos, jsonDecode(body) as Map<String, dynamic>);
          if (r != null) {
            _remoteFails = 0;
            remoteUsed = true;
            return r;
          }
        } else if (res.statusCode == 404 || res.statusCode == 405 || res.statusCode == 501) {
          _remoteOff = 1 << 62; // không có máy chủ phân tích
        } else if (res.statusCode != 503 && res.statusCode != 429) {
          _remoteFail(); // 503/429: máy chủ bận, lần này dùng engine trong app
        }
      } catch (_) {
        if (gen != _gen) return null;
        _remoteFail();
      }
    }
    remoteUsed = false;
    return search(pos, opts);
  }

  /// Dừng mọi tìm kiếm đang chạy (giết isolate, tạo mới).
  void reset() {
    _gen++;
    _httpClient?.close(force: true);
    _httpClient = null;
    _iso?.kill(priority: Isolate.immediate);
    _iso = null;
    _rx?.close();
    for (final c in _q.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _q.clear();
    _spawn();
  }

  void dispose() {
    _httpClient?.close(force: true);
    _iso?.kill(priority: Isolate.immediate);
    _rx?.close();
  }
}
