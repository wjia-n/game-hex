import 'dart:math';
import 'package:flutter/material.dart';

/// "Atelier Hex" design system (Stitch project 8029330501293044555).
/// Ceramic-tile workshop: glazed terracotta / indigo hex tiles on oiled oak,
/// dark-walnut tray, warm kiln light from the upper-left at ~45deg.
/// No neon, no flat Material look: every surface is a physical object with
/// bevels, contact shadows and ambient occlusion.
abstract final class HxTheme {
  // ---- Palette (DESIGN.md tokens) ----
  static const terracotta = Color(0xFFC96F4A); // player 1 glaze
  static const terracottaHi = Color(0xFFE08B60); // glaze highlight
  static const terracottaLo = Color(0xFF9C4E2E); // glaze shadow
  static const indigo = Color(0xFF4E6E8E); // player 2 glaze
  static const indigoHi = Color(0xFF6E93B5); // glaze highlight
  static const indigoLo = Color(0xFF354E66); // glaze shadow
  static const biscuit = Color(0xFFD9B48F); // unglazed clay plaques
  static const biscuitHi = Color(0xFFEACBA6);
  static const biscuitLo = Color(0xFFB78F63);
  static const cream = Color(0xFFEFE3D2); // plaque labels, light text
  static const walnut = Color(0xFF3A2A1E); // board tray, frames
  static const walnutDeep = Color(0xFF241812); // recesses, deep shadow
  static const oak = Color(0xFF8A6B4F); // workbench background
  static const oakDeep = Color(0xFF6E5439); // workbench shade
  static const carved = Color(0xFF2E2015); // incised lettering
  static const kiln = Color(0xFF1E1410); // deepest occlusion

  // ---- Typography ----
  static const headlineFamily = 'EBGaramond';
  static const bodyFamily = 'Newsreader';

  /// Chunky carved headline with bevel (embossed letterforms).
  static TextStyle title(double size, Color color) => TextStyle(
        fontFamily: headlineFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 2.0,
        shadows: const [
          Shadow(color: Color(0xAA000000), offset: Offset(0, 3), blurRadius: 5),
          Shadow(color: Color(0x55FFFFFF), offset: Offset(0, -1), blurRadius: 1),
        ],
      );

  static TextStyle get plaqueTitle => TextStyle(
        fontFamily: headlineFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: carved,
        letterSpacing: 1.0,
        shadows: const [
          Shadow(color: Color(0x66FFFFFF), offset: Offset(0, 1), blurRadius: 1),
          Shadow(color: Color(0x55000000), offset: Offset(0, -1), blurRadius: 1),
        ],
      );

  static TextStyle get body => const TextStyle(
        fontFamily: bodyFamily,
        fontSize: 15,
        color: carved,
        height: 1.45,
      );

  static TextStyle get caption => TextStyle(
        fontFamily: bodyFamily,
        fontSize: 12.5,
        color: cream.withValues(alpha: 0.75),
      );

  // ---- Physical light helpers ----
  /// Warm key light from upper-left: downward occlusion + top-edge lift.
  static List<BoxShadow> get plaqueShadow => const [
        BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5)),
        BoxShadow(color: Color(0x1AFFFFFF), blurRadius: 2, offset: Offset(0, -1)),
      ];

  static List<BoxShadow> get insetShadow => const [
        BoxShadow(color: Color(0xB3000000), blurRadius: 8, offset: Offset(0, 3)),
      ];

  /// Thick fired-clay plaque (buttons, score panels, settings rows).
  static BoxDecoration clayPlaque({double radius = 16}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [biscuitHi, biscuit, biscuitLo],
        ),
        border: Border.all(color: biscuitLo.withValues(alpha: 0.7), width: 1.2),
        boxShadow: plaqueShadow,
      );

  /// Carved walnut sign (settings header, tally plaque).
  static BoxDecoration walnutSign({double radius = 14}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3626), walnut, walnutDeep],
        ),
        border: Border.all(color: kiln.withValues(alpha: 0.8), width: 1.4),
        boxShadow: plaqueShadow,
      );

  /// Glaze palette per player color (0 = terracotta, 1 = indigo).
  static (Color hi, Color mid, Color lo) glaze(int player) => player == 0
      ? (terracottaHi, terracotta, terracottaLo)
      : (indigoHi, indigo, indigoLo);
}

/// Fired-clay plaque button with carved label (DESIGN.md: plaque buttons).
class ClayButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double fontSize;
  final Color? glazeColor;
  const ClayButton(
      {super.key, required this.label, required this.onTap, this.fontSize = 19, this.glazeColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 28),
        decoration: glazeColor == null
            ? HxTheme.clayPlaque()
            : BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(glazeColor, Colors.white, 0.25)!,
                    glazeColor!,
                    Color.lerp(glazeColor, Colors.black, 0.25)!,
                  ],
                ),
                boxShadow: HxTheme.plaqueShadow,
              ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: HxTheme.title(fontSize, glazeColor == null ? HxTheme.carved : HxTheme.cream),
          ),
        ),
      ),
    );
  }
}

/// Wooden peg sliding in a carved slot (DESIGN.md: physical toggles, never iOS switches).
class PegToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color pegColor;
  const PegToggle(
      {super.key, required this.value, required this.onChanged, this.pegColor = HxTheme.terracotta});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 68,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: HxTheme.walnutDeep,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HxTheme.kiln.withValues(alpha: 0.9), width: 1.5),
          boxShadow: HxTheme.insetShadow,
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(pegColor, Colors.white, 0.3)!,
                  pegColor,
                  Color.lerp(pegColor, Colors.black, 0.3)!,
                ],
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                BoxShadow(color: Color(0x33FFFFFF), blurRadius: 2, offset: Offset(0, -1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular clay token button for the thumb rail (pause / restart / undo).
class TokenButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool enabled;
  const TokenButton(
      {super.key, required this.icon, required this.onTap, this.size = 56, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HxTheme.biscuitHi, HxTheme.biscuit, HxTheme.biscuitLo],
            ),
            boxShadow: HxTheme.plaqueShadow,
            border: Border.all(color: HxTheme.biscuitLo.withValues(alpha: 0.8), width: 1.2),
          ),
          child: Icon(icon, color: HxTheme.carved, size: size * 0.44),
        ),
      ),
    );
  }
}

/// Selectable glazed hex tile chip (board-size / difficulty / color selectors).
class TileChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color glazeColor;
  final VoidCallback onTap;
  const TileChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.glazeColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [
                    Color.lerp(glazeColor, Colors.white, 0.25)!,
                    glazeColor,
                    Color.lerp(glazeColor, Colors.black, 0.25)!,
                  ]
                : [HxTheme.walnutDeep, HxTheme.walnutDeep],
          ),
          border: Border.all(
            color: selected ? HxTheme.cream.withValues(alpha: 0.7) : HxTheme.kiln,
            width: selected ? 2 : 1.2,
          ),
          boxShadow: selected ? HxTheme.plaqueShadow : HxTheme.insetShadow,
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: HxTheme.headlineFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? HxTheme.cream : HxTheme.cream.withValues(alpha: 0.55),
              shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Warm oak-workbench backdrop with kiln-light vignette, used on all screens.
class WorkbenchBackdrop extends StatelessWidget {
  final Widget child;
  const WorkbenchBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.4),
          radius: 1.3,
          colors: [Color(0xFF9A7A58), HxTheme.oak, HxTheme.oakDeep],
        ),
      ),
      child: CustomPaint(painter: _GrainPainter(), child: child),
    );
  }
}

/// Subtle oak grain streaks (cheap, static).
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 14; i++) {
      final y = size.height * (i + 0.5) / 14;
      final path = Path()..moveTo(0, y);
      path.cubicTo(size.width * 0.3, y + 6, size.width * 0.7, y - 6, size.width, y + 3);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A single glazed hex tile rendered as a physical object (used in menus).
class GlazedHexIcon extends StatelessWidget {
  final double size;
  final int player;
  const GlazedHexIcon({super.key, required this.size, required this.player});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HexIconPainter(player: player),
    );
  }
}

class _HexIconPainter extends CustomPainter {
  final int player;
  _HexIconPainter({required this.player});

  Path _hexPath(Offset c, double r) {
    final p = Path();
    for (int i = 0; i < 6; i++) {
      final a = (60 * i - 30) * 3.1415926535 / 180;
      final corner = Offset(c.dx + r * 0.94 * cos(a), c.dy + r * 0.94 * sin(a));
      if (i == 0) {
        p.moveTo(corner.dx, corner.dy);
      } else {
        p.lineTo(corner.dx, corner.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final (hi, mid, lo) = HxTheme.glaze(player);
    // contact shadow
    canvas.save();
    canvas.translate(2, 4);
    canvas.drawPath(
        _hexPath(c, r),
        Paint()
          ..color = const Color(0x55000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.restore();

    final top = _hexPath(c, r);
    canvas.drawPath(
        top,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.45),
            radius: 1.1,
            colors: [hi, mid, lo],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(
        top,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..color = lo);
    // glaze specular pill
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(-r * 0.22, -r * 0.28),
            width: r * 0.5,
            height: r * 0.28),
        Paint()..color = const Color(0x55FFFFFF));
  }

  @override
  bool shouldRepaint(covariant _HexIconPainter old) => old.player != player;
}
