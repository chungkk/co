import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/data.dart';
import '../engine/engine.dart';
import '../game/analysis.dart';
import '../game/constants.dart';
import '../game/controller.dart';
import 'home.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.title, this.trailing, this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12)});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border.all(color: pal.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(width: 8),
                  if (trailing != null)
                    Expanded(
                      child: Align(alignment: Alignment.centerRight, child: trailing!),
                    ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

TextStyle _small(BuildContext c) => TextStyle(fontSize: 12, color: c.pal.muted);

// ---------- Thầy ----------
class CoachCard extends StatelessWidget {
  final GameController g;
  const CoachCard({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = g.shownCoach;
    if (c == null) return const SizedBox.shrink();
    final accent = pal.forCls(c.cls);
    final titleColor = switch (c.cls) {
      'best' || 'inacc' || 'mistake' || 'blunder' => accent,
      _ => pal.ink,
    };
    final buttons = <Widget>[];
    if (c.confirm) {
      buttons.add(AppButton(label: 'Đi lại nước này', primary: true, compact: true, onPressed: () => g.confirmBlunder(true)));
      buttons.add(AppButton(label: 'Vẫn đi', compact: true, onPressed: () => g.confirmBlunder(false)));
    }
    if (g.mode == Mode.puzzle && g.view < 0) {
      if (g.state == 'fail') buttons.add(AppButton(label: 'Thử lại', primary: true, compact: true, onPressed: g.retryPuzzle));
      final review = g.pzCol?.review ?? false;
      if (g.state == 'done') {
        buttons.add(AppButton(label: review ? 'Thẻ tiếp theo →' : 'Bài tiếp theo →', primary: true, compact: true, onPressed: g.nextPuzzle));
        buttons.add(AppButton(label: 'Làm lại', compact: true, onPressed: () => g.loadPuzzle(g.pzIdx)));
      }
      if (review && g.pzCur != null && (g.state == 'done' || g.state == 'fail')) {
        buttons.add(AppButton(label: 'Bỏ thẻ', compact: true, onPressed: g.deleteReview));
      }
    }
    if (g.canAnalyze && g.shownCoach == g.coach) {
      buttons.add(AppButton(label: 'Phân tích ván', primary: true, compact: true, onPressed: g.analyzeGame));
    }
    if (g.mode == Mode.games && c.gmNext) {
      buttons.add(AppButton(label: 'Tiếp tục →', primary: true, compact: true, onPressed: g.gmNext));
    }
    if (g.view >= 0) buttons.add(AppButton(label: '← Về ván đang chơi', compact: true, onPressed: g.exitView));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.line),
        boxShadow: const [
          BoxShadow(color: Color(0x143C230A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x143C230A), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: titleColor),
                    ),
                    const SizedBox(height: 6),
                    if (c.busy) const _Dots(),
                    for (final l in c.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(l, style: const TextStyle(fontSize: 14.5, height: 1.45)),
                      ),
                    if (c.opening != null)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(8)),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Khai cuộc: ${c.opening!.name}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              if (c.opening!.tip != null) TextSpan(text: '\n${c.opening!.tip}'),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                    if (buttons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.only(right: 5),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pal.muted.withValues(alpha: 0.2 + 0.8 * (1 - ((_c.value - i * 0.2) % 1.0 - 0.5).abs() * 2).clamp(0.0, 1.0)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- Khai cuộc đại sư ----------
class ProBookCard extends StatelessWidget {
  final GameController g;
  const ProBookCard({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final pos = g.shownPos;
    final pm = g.proMoves(pos);
    final op = g.eco;
    final children = <Widget>[];
    if (op != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            op.name,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: pal.accent),
          ),
        ),
      );
    }
    if (g.pro == null) {
      children.add(Text('Đang tải dữ liệu…', style: _small(context)));
    } else if (g.drill != null && g.view < 0 && g.state == 'user') {
      children.add(Text('Đang luyện: hãy tự nhớ nước đại sư hay đi. Bấm "Gợi ý" nếu cần.', style: _small(context)));
    } else if (pm == null || pm.isEmpty) {
      if (g.hist.isNotEmpty) children.add(Text('Thế cờ này đã ra khỏi sách khai cuộc. Từ đây hãy tự tính toán!', style: _small(context)));
    } else {
      final tot = pm.fold<int>(0, (s, x) => s + x.n), red = pos.side == RED;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('${fmtInt(tot)} ván đại sư đến thế này. Chạm một nước để xem trên bàn cờ.', style: _small(context)),
        ),
      );
      for (final x in pm.take(6)) {
        final rw = (red ? x.w : x.l) / x.n, dr = x.d / x.n, bw = (red ? x.l : x.w) / x.n;
        final on = g.arrows.length == 1 && g.arrows[0].m == x.m;
        children.add(
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => g.toggleProArrow(x.m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              decoration: BoxDecoration(color: on ? pal.surface2 : null, borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      x.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      pct(x.share),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12.5, color: pal.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 90, child: _WdlBar(rw, dr, bw)),
                  SizedBox(
                    width: 56,
                    child: Text(
                      fmtInt(x.n),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12.5, color: pal.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              _legend(context, kRed, 'Đỏ thắng'),
              const SizedBox(width: 12),
              _legend(context, const Color(0xFFB9AB96), 'Hòa'),
              const SizedBox(width: 12),
              _legend(context, pal.blackWin, 'Đen thắng'),
            ],
          ),
        ),
      );
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Divider(height: 1, color: pal.line),
      ),
    );
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(
              child: IgnorePointer(
                ignoring: g.drill != null,
                child: Opacity(
                  opacity: g.drill != null ? 0.5 : 1,
                  child: _SelectField(text: GameController.drillOps[g.drillOp].name, onTap: () => _pickOpening(context)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: g.drill != null ? 'Dừng luyện' : 'Luyện khai cuộc',
              compact: true,
              onPressed: g.pro == null ? null : () => _toggleDrill(context),
            ),
          ],
        ),
      ),
    );
    return AppCard(
      title: 'Khai cuộc đại sư',
      trailing: Text('từ ${fmtInt(g.pro?.games ?? 104186)} ván giải đấu', style: _small(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  void _pickOpening(BuildContext context) {
    showPickerSheet<int>(
      context,
      title: 'Khai cuộc muốn luyện',
      items: [
        for (var i = 0; i < GameController.drillOps.length; i++)
          (i, GameController.drillOps[i].name, GameController.drillOps[i].seq.join(', ')),
      ],
      selected: g.drillOp,
      onPick: g.setDrillOp,
    );
  }

  Future<void> _toggleDrill(BuildContext context) async {
    if (g.drill != null) return g.stopDrill();
    if (g.hist.length > 2 && g.result == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: const Text('Bỏ ván đang chơi để luyện khai cuộc?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Luyện')),
          ],
        ),
      );
      if (ok != true) return;
    }
    g.startDrill(g.drillOp);
  }

  Widget _legend(BuildContext c, Color col, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 11.5, color: c.pal.muted)),
    ],
  );
}

class _WdlBar extends StatelessWidget {
  final double r, d, b;
  const _WdlBar(this.r, this.d, this.b);
  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    int f(double x) => (x * 1000).round().clamp(0, 1000);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 9,
        color: pal.line,
        child: Row(
          children: [
            if (f(r) > 0)
              Expanded(
                flex: f(r),
                child: Container(color: kRed),
              ),
            if (f(d) > 0)
              Expanded(
                flex: f(d),
                child: Container(color: const Color(0xFFB9AB96)),
              ),
            if (f(b) > 0)
              Expanded(
                flex: f(b),
                child: Container(color: pal.blackWin),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- Bài tập ----------
class PuzzleCard extends StatelessWidget {
  final GameController g;
  const PuzzleCard({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final col = g.pzCol;
    if (col == null)
      return const AppCard(
        title: 'Bài tập',
        child: Center(child: CircularProgressIndicator()),
      );
    final items = col.items;
    // nhóm: (tiêu đề, các chỉ số bài)
    final groups = <(String, List<int>)>[];
    if (col.review) {
      final due = [for (var i = 0; i < items.length; i++) if (!g.isSolved(i)) i];
      final later = [for (var i = 0; i < items.length; i++) if (g.isSolved(i)) i];
      if (due.isNotEmpty) groups.add(('ĐẾN HẠN ÔN · ${due.length} THẺ', due));
      if (later.isNotEmpty) groups.add(('ĐÃ THUỘC, CHỜ ÔN LẠI · ${later.length} THẺ', later));
    } else {
      final byN = <int, List<int>>{};
      for (var i = 0; i < items.length; i++) {
        byN.putIfAbsent(items[i].n, () => []).add(i);
      }
      for (final n in byN.keys.toList()..sort()) {
        groups.add(('CHIẾU BÍ $n NƯỚC · ${byN[n]!.length} BÀI', byN[n]!));
      }
    }
    final weak = col.review ? const <({String t, int ok, int tot})>[] : g.weakThemes;
    return AppCard(
      title: 'Bài tập',
      trailing: Text(
        col.review ? '${items.length - g.solvedCount} thẻ đến hạn / ${items.length}' : 'Đã giải ${g.solvedCount}/${items.length}',
        style: _small(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectField(text: '${col.title} (${items.length})', onTap: () => _pickCollection(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: AppButton(label: 'Trước', icon: Icons.chevron_left, compact: true, onPressed: g.pzIdx > 0 ? g.prevPuzzle : null),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 14,
                child: AppButton(label: 'Xem lời giải', compact: true, onPressed: g.state == 'demo' ? null : g.showSolution),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 10,
                child: AppButton(label: 'Sau', icon: Icons.chevron_right, trailingIcon: true, compact: true, onPressed: g.nextPuzzle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (weak.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text('Chủ đề cần luyện (giải đúng ngay lần đầu):', style: _small(context)),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in weak)
                  ActionChip(
                    label: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${w.t} '),
                          TextSpan(
                            text: '${w.ok}/${w.tot}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: pal.forCls('mistake')),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: pal.surface2,
                    side: BorderSide(color: pal.line),
                    shape: const StadiumBorder(),
                    onPressed: () => g.practiceTheme(w.t),
                  ),
              ],
            ),
          ],
          for (final (title, idxs) in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(
                title,
                style: TextStyle(fontSize: 11.5, color: pal.muted, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [for (final i in idxs) _PzChip(i: i, ok: g.isSolved(i), cur: i == g.pzIdx, onTap: () => g.loadPuzzle(i))],
            ),
          ],
        ],
      ),
    );
  }

  void _pickCollection(BuildContext context) {
    showPickerSheet<String>(
      context,
      title: 'Bộ bài tập',
      items: [for (final c in g.pzCols) (c.id, c.title, '${c.count} ${c.id == reviewColId ? 'thẻ' : 'bài'}')],
      selected: g.pzCol?.id,
      onPick: (id) => g.openCollection(id, 0),
    );
  }
}

class _PzChip extends StatelessWidget {
  final int i;
  final bool ok, cur;
  final VoidCallback onTap;
  const _PzChip({required this.i, required this.ok, required this.cur, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ok ? pal.cBest : pal.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cur ? pal.accent : (ok ? pal.cBest : pal.line), width: cur ? 2.5 : 1),
        ),
        child: Text(
          '${i + 1}',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ok ? Colors.white : pal.ink),
        ),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SelectField({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: pal.surface,
          border: Border.all(color: pal.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.unfold_more, size: 20, color: pal.muted),
          ],
        ),
      ),
    );
  }
}

Future<void> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String, String)> items,
  required T? selected,
  required ValueChanged<T> onPick,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 600),
    isScrollControlled: true,
    backgroundColor: context.pal.surface,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (c, sc) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView.builder(
              controller: sc,
              itemCount: items.length,
              itemBuilder: (c, i) {
                final (v, t, sub) = items[i];
                final on = v == selected;
                return ListTile(
                  title: Text(t, style: TextStyle(fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text(sub, style: _small(c)),
                  trailing: on ? Icon(Icons.check, color: c.pal.accent) : null,
                  onTap: () {
                    Navigator.pop(c);
                    onPick(v);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------- Ván đại sư ----------
class GamesCard extends StatelessWidget {
  final GameController g;
  const GamesCard({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final col = g.gmCol, game = g.gmGame;
    if (col == null || game == null)
      return const AppCard(
        title: 'Ván đại sư',
        child: Center(child: CircularProgressIndicator()),
      );
    return AppCard(
      title: 'Ván đại sư',
      trailing: Text('${g.gmPly}/${g.gmMoves.length}', style: _small(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectField(text: '${col.title} (${col.games.length})', onTap: () => _pickCollection(context)),
          const SizedBox(height: 8),
          _SelectField(text: 'Ván ${g.gmGi + 1}. ${game.r ?? '?'} – ${game.b ?? '?'}', onTap: () => _pickGame(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 46,
                child: AppButton(label: '', icon: Icons.first_page, compact: true, onPressed: g.state == 'ai' ? null : g.gmFirst),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppButton(
                  label: g.gmGuess ? 'Đoán: ${sideName(g.gmSide)}' : 'Đoán nước',
                  icon: Icons.psychology_alt_outlined,
                  compact: true,
                  color: g.gmGuess ? pal.cBest : null,
                  onPressed: g.state == 'ai' ? null : g.gmToggleGuess,
                ),
              ),
              const SizedBox(width: 6),
              AppButton(label: 'Bên', icon: Icons.swap_horiz, compact: true, onPressed: g.state == 'ai' ? null : g.gmToggleSide),
              const SizedBox(width: 6),
              SizedBox(
                width: 46,
                child: AppButton(label: '', icon: Icons.last_page, compact: true, onPressed: g.state == 'ai' ? null : g.gmLast),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Chỉ hỏi nước then chốt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('Khi luyện đoán nước: tự đi các nước thường, chỉ dừng ở thế có một nước tốt rõ rệt', style: _small(context)),
              value: g.gmKeyOnly,
              onChanged: g.state == 'ai' ? null : (_) => g.gmToggleKey(),
            ),
          ),
          const SizedBox(height: 4),
          AppButton(
            label: 'Đánh tiếp với máy từ thế này',
            icon: Icons.sports_esports_outlined,
            compact: true,
            onPressed: g.state == 'ai' ? null : g.gmPlay,
          ),
        ],
      ),
    );
  }

  void _pickCollection(BuildContext context) {
    final idx = g.gmIndex ?? [];
    showPickerSheet<String>(
      context,
      title: 'Bộ sưu tập',
      items: [for (final c in idx) (c.id, c.title, '${c.count} ván')],
      selected: g.gmCol?.id,
      onPick: (id) => g.gmOpenCol(id, 0),
    );
  }

  void _pickGame(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 600),
      isScrollControlled: true,
      backgroundColor: context.pal.surface,
      builder: (c) => _GamePicker(g: g),
    );
  }
}

class _GamePicker extends StatefulWidget {
  final GameController g;
  const _GamePicker({required this.g});
  @override
  State<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends State<_GamePicker> {
  String f = '';

  @override
  Widget build(BuildContext context) {
    final g = widget.g, pal = context.pal;
    final games = g.gmCol!.games;
    final q = f.trim().toLowerCase();
    final rows = <(int, String, String)>[];
    for (var i = 0; i < games.length; i++) {
      final x = games[i];
      final label = '${x.r ?? '?'} – ${x.b ?? '?'}';
      final sub = [
        x.res == 1
            ? '1-0'
            : x.res == -1
            ? '0-1'
            : x.res == 0
            ? '½-½'
            : '',
        x.d ?? '',
        x.eco != null ? (x.eco!.split(' · ').length > 1 ? x.eco!.split(' · ')[1] : x.eco!) : (x.t ?? ''),
      ].where((s) => s.isNotEmpty).join(' · ');
      if (q.isNotEmpty && !('$label $sub').toLowerCase().contains(q)) continue;
      rows.add((i, label, sub));
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (c, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => f = v),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên kỳ thủ, khai cuộc…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: pal.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: pal.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: pal.line),
                ),
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text('Không có ván phù hợp.', style: _small(context)))
                : ListView.builder(
                    controller: sc,
                    itemCount: rows.length,
                    itemBuilder: (c, k) {
                      final (i, label, sub) = rows[k];
                      final on = i == g.gmGi;
                      return ListTile(
                        dense: true,
                        selected: on,
                        selectedTileColor: pal.surface2,
                        title: Text(
                          '${i + 1}. $label',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: pal.ink),
                        ),
                        subtitle: sub.isEmpty ? null : Text(sub, style: _small(c)),
                        onTap: () {
                          Navigator.pop(c);
                          g.gmLoad(i);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------- Danh sách nước đi ----------
class MovesCard extends StatelessWidget {
  final GameController g;
  const MovesCard({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final h = g.hist;
    final rows = <Widget>[];
    Widget cell(int j) {
      if (j >= h.length) return const Expanded(child: SizedBox());
      final e = h[j];
      final on = g.mode == Mode.games ? j == g.gmPly - 1 : g.view == j;
      final c = e.by == 'user' ? e.cls : null;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => g.tapMoveInList(j),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: on ? pal.surface2 : null,
              borderRadius: BorderRadius.circular(6),
              border: on ? Border.all(color: kArrowAlt, width: 2) : null,
            ),
            child: Row(
              children: [
                if (c != null) ...[_Badge(c), const SizedBox(width: 4)],
                Flexible(
                  child: Text(
                    e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: e.by == 'ai' && g.mode == Mode.play ? pal.muted : pal.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    for (var i = 0; i < h.length; i += 2) {
      rows.add(
        Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${i ~/ 2 + 1}.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: pal.muted),
              ),
            ),
            const SizedBox(width: 4),
            cell(i),
            const SizedBox(width: 4),
            cell(i + 1),
          ],
        ),
      );
    }
    return AppCard(
      title: 'Nước đi',
      trailing: Text(g.mode == Mode.games ? 'chạm để tới nước đó' : 'chạm vào nước để xem lại', style: _small(context)),
      child: rows.isEmpty
          ? Text('Chưa có nước nào.', style: TextStyle(color: pal.muted))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

class _Badge extends StatelessWidget {
  final String c;
  const _Badge(this.c);
  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final book = c == 'book';
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(color: book ? Colors.transparent : pal.forCls(c), borderRadius: BorderRadius.circular(5)),
      child: Text(
        cls[c]!.icon,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, fontStyle: FontStyle.normal),
      ),
    );
  }
}

// ---------- Nhập ván / thế cờ ----------
class ImportCard extends StatefulWidget {
  final GameController g;
  const ImportCard({super.key, required this.g});
  @override
  State<ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<ImportCard> {
  final _text = TextEditingController();
  int _side = RED; // RED, BLACK hoặc 0 = bên tới lượt
  String _msg = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final g = widget.g;
    if (g.hist.length > 2 && g.result == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: const Text('Bỏ ván đang chơi để nhập ván mới?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Nhập')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final err = g.importGame(_text.text, _side);
    setState(() => _msg = err ?? '');
    if (err == null) _text.clear();
  }

  Future<void> _copyFen() async {
    await Clipboard.setData(ClipboardData(text: widget.g.currentFen));
    setState(() => _msg = 'Đã chép FEN thế cờ hiện tại.');
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) _text.text = d!.text!;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const sides = [(RED, 'Đỏ', ''), (BLACK, 'Đen', ''), (0, 'Bên tới lượt', 'bên đi nước tiếp theo')];
    return AppCard(
      title: 'Nhập ván / thế cờ của bạn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dán FEN, biên bản nước đi (Pháo 2 bình 5…, P2-5…, C2.5…, 炮二平五…) hoặc FEN kèm nước đi. '
            'Sau đó đánh tiếp với máy hoặc bấm "Phân tích ván" để thầy chấm từng nước.',
            style: _small(context),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: '1. Pháo 2 bình 5  Mã 8 tiến 7\n2. Mã 2 tiến 3  Xe 9 bình 8 …',
              isDense: true,
              filled: true,
              fillColor: pal.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: pal.line)),
              suffixIcon: IconButton(tooltip: 'Dán', icon: const Icon(Icons.content_paste, size: 18), onPressed: _paste),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SelectField(
                  text: 'Tôi cầm: ${sides.firstWhere((x) => x.$1 == _side).$2}',
                  onTap: () => showPickerSheet<int>(
                    context,
                    title: 'Tôi cầm quân',
                    items: sides,
                    selected: _side,
                    onPick: (v) => setState(() => _side = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(label: 'Nhập', primary: true, compact: true, onPressed: _import),
              const SizedBox(width: 6),
              AppButton(label: 'Chép FEN', compact: true, onPressed: _copyFen),
            ],
          ),
          if (_msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_msg, style: TextStyle(fontSize: 12.5, color: pal.forCls('mistake'))),
            ),
        ],
      ),
    );
  }
}
