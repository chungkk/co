import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../game/analysis.dart';
import '../game/constants.dart';
import '../game/controller.dart';
import 'board.dart';
import 'panels.dart';
import 'theme.dart';

class HomePage extends StatelessWidget {
  final GameController g;
  const HomePage({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final pal = context.pal;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                const Logo(size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cờ Tướng', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                      Text(
                        switch (g.mode) {
                          Mode.play => 'Luyện cùng máy, có thầy chỉ nước',
                          Mode.puzzle => 'Bài tập sát cục',
                          Mode.games => 'Ván đại sư',
                        },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: pal.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (g.mode == Mode.play)
                TextButton.icon(
                  onPressed: () => _confirmNewGame(context),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Ván mới', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              IconButton(tooltip: 'Tùy chọn', icon: const Icon(Icons.tune), onPressed: () => showSettings(context, g)),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                if (w > h && w >= 600) return _landscape(context, w, h);
                if (w >= 600) return _tabletPortrait(context, w, h);
                return _phone(context);
              },
            ),
          ),
          bottomNavigationBar: _useRail(context) ? null : _bottomNav(),
        );
      },
    );
  }

  bool _useRail(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return s.width > s.height && s.width >= 600;
  }

  static const _dest = [
    (Icons.sports_esports_outlined, Icons.sports_esports, 'Đấu với máy'),
    (Icons.extension_outlined, Icons.extension, 'Sát cục'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Ván đại sư'),
  ];

  Widget _bottomNav() => NavigationBar(
    height: 64,
    selectedIndex: g.mode.index,
    onDestinationSelected: (i) => g.setMode(Mode.values[i]),
    destinations: [for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
  );

  Widget _rail(BuildContext context, {required bool extended}) {
    final pal = context.pal;
    return NavigationRail(
      backgroundColor: pal.surface,
      extended: extended,
      minExtendedWidth: 200,
      selectedIndex: g.mode.index,
      onDestinationSelected: (i) => g.setMode(Mode.values[i]),
      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      indicatorColor: pal.accent.withValues(alpha: 0.15),
      selectedLabelTextStyle: TextStyle(fontFamily: kFont, fontSize: 13, fontWeight: FontWeight.w700, color: pal.ink),
      unselectedLabelTextStyle: TextStyle(fontFamily: kFont, fontSize: 13, fontWeight: FontWeight.w500, color: pal.muted),
      destinations: [for (final d in _dest) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))],
    );
  }

  Widget _boardBlock({required double maxWidth}) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BoardView(g: g),
        if (g.mode == Mode.play)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: EvalBar(g: g),
          ),
      ],
    ),
  );

  // iPhone dọc: một cột cuộn
  Widget _phone(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
    children: [
      if (g.mode == Mode.play) PlayControls(g: g),
      _boardBlock(maxWidth: double.infinity),
      const SizedBox(height: 10),
      ..._controls(),
      const SizedBox(height: 12),
      ..._details(),
    ],
  );

  // iPad dọc: bàn cờ lớn ở giữa, bên dưới chia hai cột
  Widget _tabletPortrait(BuildContext context, double w, double h) {
    final boardW = math.min(math.min(w - 48, 680.0), (h - 380) * 900 / 1100);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.max(boardW, 560)),
            child: g.mode == Mode.play ? PlayControls(g: g) : const SizedBox.shrink(),
          ),
        ),
        Center(child: _boardBlock(maxWidth: boardW)),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _controls()),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _details()),
            ),
          ],
        ),
      ],
    );
  }

  // Ngang: thanh chế độ bên trái, bàn cờ cao hết màn hình, bảng bên phải
  Widget _landscape(BuildContext context, double w, double h) {
    final extended = w >= 1200;
    final railW = extended ? 200.0 : 96.0;
    final evalH = g.mode == Mode.play ? 30.0 : 0.0;
    var boardW = (h - 24 - evalH) * 900 / 1100;
    final panelW = (w - railW - boardW - 48).clamp(0.0, 520.0);
    if (panelW < 340) boardW = math.max(240, w - railW - 340 - 48);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rail(context, extended: extended),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
                child: _boardBlock(maxWidth: boardW),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 24),
                    children: [
                      if (g.mode == Mode.play) PlayControls(g: g),
                      ..._controls(),
                      const SizedBox(height: 12),
                      ..._details(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _controls() => [
    StatusLine(g: g),
    const SizedBox(height: 8),
    ActionButtons(g: g),
    const SizedBox(height: 12),
    CoachCard(g: g),
  ];

  List<Widget> _details() => [
    if (g.mode == Mode.play) ProBookCard(g: g),
    if (g.mode == Mode.puzzle) PuzzleCard(g: g),
    if (g.mode == Mode.games) GamesCard(g: g),
    const SizedBox(height: 12),
    MovesCard(g: g),
    const SizedBox(height: 12),
    if (g.mode == Mode.play) ...[ImportCard(g: g), const SizedBox(height: 12)],
    const Credits(),
  ];

  Future<void> _confirmNewGame(BuildContext context) async {
    if (g.hist.length > 2 && g.result == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ván mới?'),
          content: const Text('Bỏ ván đang chơi và bắt đầu ván mới?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ván mới')),
          ],
        ),
      );
      if (ok != true) return;
    }
    g.newGame(keepSide: true);
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: kPieceBg,
      border: Border.all(color: kRed, width: size * 0.07),
      boxShadow: const [BoxShadow(color: Color(0x223C230A), blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: Text(
      '帥',
      textScaler: TextScaler.noScaling,
      style: TextStyle(fontFamily: kHanFont, fontWeight: FontWeight.w700, fontSize: size * 0.52, color: kRed, height: 1),
    ),
  );
}

class PlayControls extends StatelessWidget {
  final GameController g;
  const PlayControls({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _Picker<int>(
              label: 'Cấp độ',
              value: g.level,
              items: {for (var i = 1; i <= 5; i++) i: '$i · ${levels[i]!.name}'},
              onChanged: g.setLevel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Picker<int>(
              label: 'Cầm quân',
              value: g.userSide,
              items: const {RED: 'Đỏ (đi trước)', BLACK: 'Đen'},
              onChanged: (s) {
                if (s != g.userSide) g.setSide(s);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Picker<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  const _Picker({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      color: pal.surface,
      itemBuilder: (_) => [for (final e in items.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: pal.surface,
          border: Border.all(color: pal.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: pal.muted)),
                  Text(
                    items[value] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more, color: pal.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class EvalBar extends StatelessWidget {
  final GameController g;
  const EvalBar({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    var s = g.lastScore;
    if (g.result != null) s = g.result!.winner == 0 ? 0 : (g.result!.winner == g.userSide ? MATE : -MATE);
    final cs = clampS(s);
    final frac = 0.5 + 0.5 * _tanh(cs / 600);
    final text = s.abs() > MATE - 500
        ? (s > 0 ? 'Bạn sắp thắng' : 'Bạn sắp thua')
        : cs.abs() < 40
        ? 'Cân bằng'
        : '${cs > 0 ? 'Bạn ưu thế ' : 'Máy ưu thế '}${(cs.abs() / 100).toStringAsFixed(1)}';
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: pal.line, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFF2B211A)),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      widthFactor: frac,
                      heightFactor: 1,
                      alignment: Alignment.centerLeft,
                      child: Container(color: const Color(0xFFF4E7CF)),
                    ),
                    Align(child: Container(width: 2, color: pal.accent.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  static double _tanh(double x) {
    final a = math.exp((2 * x).clamp(-40.0, 40.0));
    return (a - 1) / (a + 1);
  }
}

class StatusLine extends StatefulWidget {
  final GameController g;
  const StatusLine({super.key, required this.g});
  @override
  State<StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<StatusLine> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, pal = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(
              g.statusText,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: g.statusAlert ? pal.cBlunder : pal.ink),
            ),
          ),
          if (g.statusThinking)
            FadeTransition(
              opacity: Tween(begin: 0.2, end: 1.0).animate(_blink),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: pal.accent),
              ),
            ),
        ],
      ),
    );
  }
}

class ActionButtons extends StatelessWidget {
  final GameController g;
  const ActionButtons({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final (pLabel, pIcon) = switch (g.mode) {
      Mode.games => ('Tiến', Icons.chevron_right),
      _ => ('Gợi ý', Icons.lightbulb_outline),
    };
    final (sLabel, sIcon) = switch (g.mode) {
      Mode.puzzle => ('Làm lại bài', Icons.replay),
      Mode.games => ('Lùi', Icons.chevron_left),
      Mode.play => ('Đi lại', Icons.undo),
    };
    final primary = AppButton(
      label: pLabel,
      icon: pIcon,
      primary: true,
      onPressed: g.canHint ? g.primaryAction : null,
      trailingIcon: g.mode == Mode.games,
    );
    final secondary = AppButton(label: sLabel, icon: sIcon, onPressed: g.canUndo ? g.secondaryAction : null);
    return Row(
      children: [
        if (g.mode == Mode.games) ...[
          Expanded(child: secondary),
          const SizedBox(width: 8),
          Expanded(child: primary),
        ] else ...[
          Expanded(child: primary),
          const SizedBox(width: 8),
          Expanded(child: secondary),
        ],
      ],
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool primary, trailingIcon, compact;
  final VoidCallback? onPressed;
  final Color? color;
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.primary = false,
    this.trailingIcon = false,
    this.compact = false,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final bg = color ?? (primary ? pal.accent : pal.surface);
    final fg = primary || color != null ? Colors.white : pal.ink;
    final children = <Widget>[
      if (icon != null && !trailingIcon) Icon(icon, size: compact ? 18 : 20),
      if (icon != null && !trailingIcon && label.isNotEmpty) const SizedBox(width: 6),
      if (label.isNotEmpty) Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      if (icon != null && trailingIcon && label.isNotEmpty) const SizedBox(width: 4),
      if (icon != null && trailingIcon) Icon(icon, size: compact ? 18 : 20),
    ];
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: primary || color != null ? bg : pal.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 38 : 46),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: compact ? 13.5 : 15),
                child: IconTheme.merge(
                  data: IconThemeData(color: fg),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: children),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Credits extends StatelessWidget {
  const Credits({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      'Dữ liệu ván cờ, cờ thế: kho cộng đồng của vietcotuong.com (nguồn gốc dpxq.com và các sách cờ). '
      'Bộ 68 Sát pháp cơ bản: Jim Png Hau Cheng (xqinenglish.com). Tên ván, tên kỳ thủ được phiên âm Hán-Việt tự động.',
      style: TextStyle(fontSize: 11.5, color: context.pal.muted),
    ),
  );
}

Future<void> showSettings(BuildContext context, GameController g) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 600),
    backgroundColor: context.pal.surface,
    isScrollControlled: true,
    builder: (c) => ListenableBuilder(
      listenable: g,
      builder: (c, _) {
        final pal = c.pal;
        Widget tog(String t, bool v, ValueChanged<bool> f, {String? sub}) => SwitchListTile.adaptive(
          value: v,
          onChanged: f,
          title: Text(t, style: const TextStyle(fontSize: 15)),
          subtitle: sub == null ? null : Text(sub, style: TextStyle(fontSize: 12.5, color: pal.muted)),
          activeTrackColor: pal.accent,
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('Tùy chọn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                tog('Hỏi lại khi tôi đi nước hỏng', g.opt.warn, (v) => g.setOptions(warn: v), sub: 'Chỉ áp dụng khi đấu với máy'),
                tog('Viền đỏ quân của tôi đang bị đe dọa', g.opt.threats, (v) => g.setOptions(threats: v)),
                tog('Quân cờ chữ Hán', g.opt.han, (v) => g.setOptions(hanChars: v), sub: 'Tắt: dùng chữ Việt X, M, P…'),
                tog('Âm thanh và rung', g.opt.sound, (v) => g.setOptions(sound: v)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    switch (g.engine.remoteUsed) {
                      true => 'Máy chấm: Pikafish trên máy chủ (mạnh, cần mạng).',
                      false => 'Máy chấm: engine trong app (không kết nối được máy chủ Pikafish).',
                      null => 'Máy chấm: Pikafish trên máy chủ khi có mạng, engine trong app khi không có mạng.',
                    },
                    style: TextStyle(fontSize: 13, color: pal.muted),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Ký hiệu nước đi: Quân · cột · tiến/thoái/bình · số. Cột đánh số 1–9 từ phải sang trái theo phía mỗi bên '
                    '(xem số ở mép bàn cờ). Ví dụ "Pháo 2 bình 5" là Pháo ở cột 2 đi ngang sang cột 5.',
                    style: TextStyle(fontSize: 13, color: pal.muted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
