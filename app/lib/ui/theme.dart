import 'package:flutter/material.dart';

/// Bảng màu lấy từ site/css/style.css (sáng & tối).
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color bg, surface, surface2, ink, muted, line, accent, wood1, wood2, grid;
  final Color cBest, cGood, cBook, cInacc, cMistake, cBlunder;
  final Color blackWin;
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.wood1,
    required this.wood2,
    required this.grid,
    required this.cBest,
    required this.cGood,
    required this.cBook,
    required this.cInacc,
    required this.cMistake,
    required this.cBlunder,
    required this.blackWin,
  });

  static const light = Palette(
    bg: Color(0xFFF4EDE1),
    surface: Color(0xFFFFFAF1),
    surface2: Color(0xFFF7EFE0),
    ink: Color(0xFF2B211A),
    muted: Color(0xFF7D6C5C),
    line: Color(0xFFE3D5BF),
    accent: Color(0xFFA3311F),
    wood1: Color(0xFFE9C88F),
    wood2: Color(0xFFD9AE6C),
    grid: Color(0xFF6B4423),
    cBest: Color(0xFF1F8A4C),
    cGood: Color(0xFF4F8A2A),
    cBook: Color(0xFF7A5A2F),
    cInacc: Color(0xFFB8860B),
    cMistake: Color(0xFFD9662B),
    cBlunder: Color(0xFFC0262D),
    blackWin: Color(0xFF2B211A),
  );

  static const dark = Palette(
    bg: Color(0xFF17130F),
    surface: Color(0xFF221C16),
    surface2: Color(0xFF2A231C),
    ink: Color(0xFFF1E7D8),
    muted: Color(0xFFA8977F),
    line: Color(0xFF3A3027),
    accent: Color(0xFFE0644C),
    wood1: Color(0xFFC9A066),
    wood2: Color(0xFFB58949),
    grid: Color(0xFF4A2C13),
    cBest: Color(0xFF4CC27F),
    cGood: Color(0xFF8FC25A),
    cBook: Color(0xFFC9A066),
    cInacc: Color(0xFFE0B13A),
    cMistake: Color(0xFFF08A4B),
    cBlunder: Color(0xFFFF5A5F),
    blackWin: Color(0xFFE9DCC6),
  );

  Color forCls(String? c) => switch (c) {
    'best' => cBest,
    'good' => cGood,
    'book' => cBook,
    'inacc' => cInacc,
    'mistake' => cMistake,
    'blunder' => cBlunder,
    _ => accent,
  };

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

// Màu cố định (không đổi theo sáng/tối), giống bản web
const kRed = Color(0xFFB3261E);
const kBlack = Color(0xFF1F1A17);
const kPieceBg = Color(0xFFFBF1DC);
const kPieceEdge = Color(0xFFC9A46A);
const kArrowBest = Color(0xFF1F8A4C);
const kArrowAlt = Color(0xFF2F6FB5);
const kArrowBad = Color(0xFFD9662B);
const kArrowPlayed = Color(0xFF8A7D70);

const kFont = 'BeVietnamPro';
const kHanFont = 'NotoSerifSC';

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    fontFamily: kFont,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: b,
      primary: p.accent,
      onPrimary: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
    ),
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink, fontFamily: kFont),
    dividerColor: p.line,
    appBarTheme: AppBarTheme(backgroundColor: p.bg, foregroundColor: p.ink, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.accent.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w600, color: p.ink)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : null),
    ),
  );
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}
