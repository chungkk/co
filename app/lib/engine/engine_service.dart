// Chạy tìm kiếm trong Isolate riêng (tương đương Web Worker bên bản web).
import 'dart:async';
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

class EngineService {
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

  /// Dừng mọi tìm kiếm đang chạy (giết isolate, tạo mới).
  void reset() {
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
    _iso?.kill(priority: Isolate.immediate);
    _rx?.close();
  }
}
