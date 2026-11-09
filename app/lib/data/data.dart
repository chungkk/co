// Nạp dữ liệu đóng gói trong app (assets/data, sao chép từ site/data).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/engine.dart';

// ---------- Sách khai cuộc đại sư ----------
class BookMove {
  final int m, n, w, d, l;
  final double share;
  final String name;
  BookMove(this.m, this.n, this.w, this.d, this.l, this.share, this.name);
}

class ProBook {
  final int games;
  final Map<String, List<List<int>>> pos;
  final Map<String, String> eco;
  final Map<String, String> names;
  ProBook(this.games, this.pos, this.eco, this.names);

  static Future<ProBook> load() async {
    final s = await rootBundle.loadString('assets/data/book.json');
    return compute(_parseBook, s);
  }

  List<BookMove>? movesFor(Pos p) {
    final e = pos[p.key];
    if (e == null) return null;
    final legal = p.legalMoves();
    final tot = e.fold<int>(0, (s, x) => s + x[1]);
    return [
      for (final x in e)
        if (legal.contains(x[0])) BookMove(x[0], x[1], x[2], x[3], x[4], x[1] / tot, p.moveName(x[0])),
    ];
  }
}

ProBook _parseBook(String s) {
  final d = jsonDecode(s) as Map<String, dynamic>;
  final pos = <String, List<List<int>>>{};
  (d['pos'] as Map<String, dynamic>).forEach((k, v) {
    pos[k] = [for (final x in v as List) (x as List).cast<int>()];
  });
  return ProBook(
    d['games'] as int,
    pos,
    (d['eco'] as Map<String, dynamic>).cast<String, String>(),
    (d['names'] as Map<String, dynamic>).cast<String, String>(),
  );
}

// ---------- Bài tập sát cục ----------
class Puzzle {
  final String fen;
  final int n;
  final List<int> sol;
  final String? theme, name;
  final List<(int, String)> notes;
  Puzzle(this.fen, this.n, this.sol, this.theme, this.name, this.notes);

  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
    j['fen'] as String,
    j['n'] as int,
    (j['sol'] as List).cast<int>(),
    j['theme'] as String?,
    j['name'] as String?,
    [for (final x in (j['notes'] as List?) ?? const []) ((x as List)[0] as int, x[1] as String)],
  );
}

class PuzzleCollection {
  final String id, title;
  final String? source;
  final List<Puzzle> items;
  PuzzleCollection(this.id, this.title, this.source, this.items);
}

class CollectionInfo {
  final String id, title;
  final int count;
  CollectionInfo(this.id, this.title, this.count);
}

Future<List<CollectionInfo>> loadPuzzleIndex() async {
  final list = jsonDecode(await rootBundle.loadString('assets/data/puzzles/index.json')) as List;
  return [
    CollectionInfo('thuc-chien', 'Thực chiến (máy tự đánh)', 70),
    for (final c in list) CollectionInfo(c['id'] as String, c['title'] as String, c['count'] as int),
  ];
}

Future<PuzzleCollection> loadPuzzleCollection(String id) async {
  if (id == 'thuc-chien') {
    final list = jsonDecode(await rootBundle.loadString('assets/data/puzzles/thuc-chien.json')) as List;
    return PuzzleCollection(id, 'Thực chiến (máy tự đánh)', 'Đào từ ván máy tự đánh, engine kiểm chứng', [
      for (final x in list) Puzzle.fromJson(x as Map<String, dynamic>),
    ]);
  }
  final d = jsonDecode(await rootBundle.loadString('assets/data/puzzles/$id.json')) as Map<String, dynamic>;
  return PuzzleCollection(d['id'] as String, d['title'] as String, d['source'] as String?, [
    for (final x in d['items'] as List) Puzzle.fromJson(x as Map<String, dynamic>),
  ]);
}

// ---------- Ván đại sư ----------
class MasterGame {
  final String m;
  final String? r, b, ev, d, eco, t, fen;
  final int? res;
  final List<(int, String)> notes;
  MasterGame(this.m, this.r, this.b, this.ev, this.d, this.eco, this.t, this.fen, this.res, this.notes);

  factory MasterGame.fromJson(Map<String, dynamic> j) => MasterGame(
    j['m'] as String,
    j['r'] as String?,
    j['b'] as String?,
    j['ev'] as String?,
    j['d'] as String?,
    j['eco'] as String?,
    j['t'] as String?,
    j['fen'] as String?,
    j['res'] as int?,
    [for (final x in (j['notes'] as List?) ?? const []) ((x as List)[0] as int, x[1] as String)],
  );

  List<int> decodeMoves() {
    final out = <int>[];
    for (var k = 0; k + 4 <= m.length; k += 4) {
      final s = m.substring(k, k + 4).codeUnits.map((c) => c - 48).toList();
      out.add((s[1] * 9 + s[0]) | ((s[3] * 9 + s[2]) << 7));
    }
    return out;
  }
}

class GameCollection {
  final String id, title;
  final List<MasterGame> games;
  GameCollection(this.id, this.title, this.games);
}

Future<List<CollectionInfo>> loadGameIndex() async {
  final list = jsonDecode(await rootBundle.loadString('assets/data/games/index.json')) as List;
  return [for (final c in list) CollectionInfo(c['id'] as String, c['title'] as String, c['count'] as int)];
}

Future<GameCollection> loadGameCollection(String id) async {
  final s = await rootBundle.loadString('assets/data/games/$id.json');
  return compute(_parseGames, s);
}

GameCollection _parseGames(String s) {
  final d = jsonDecode(s) as Map<String, dynamic>;
  return GameCollection(d['id'] as String, d['title'] as String, [
    for (final x in d['games'] as List) MasterGame.fromJson(x as Map<String, dynamic>),
  ]);
}
