import 'package:flutter/material.dart';
import '../players/player.dart';
import '../theme/game_theme.dart';

/// Big friendly gradient button used across all games.
class WajihaButton extends StatelessWidget {
  final String label;
  final String? emoji;
  final VoidCallback onTap;
  final bool primary;
  final double fontSize;

  const WajihaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.emoji,
    this.primary = true,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        decoration: BoxDecoration(
          gradient: primary ? t.headerGradient : null,
          color: primary ? null : t.surface,
          borderRadius: t.radius,
          border: primary ? null : Border.all(color: t.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: (primary ? t.primary : t.muted).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          '${emoji ?? ''} $label'.trim(),
          style: TextStyle(
            color: primary ? (t.dark ? Colors.black : Colors.white) : t.text,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Round icon button for the home-screen action row.
class CircleAction extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const CircleAction({super.key, required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: t.radius,
              border: Border.all(color: t.primary.withValues(alpha: 0.4), width: 2),
              boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: t.muted, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Row of player score chips shown above the board.
class ScoreChips extends StatelessWidget {
  final List<Player> players;
  final int activeIndex;

  const ScoreChips({super.key, required this.players, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < players.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: i == activeIndex ? players[i].color.withValues(alpha: 0.25) : t.surface,
              borderRadius: t.radius,
              border: Border.all(
                color: i == activeIndex ? players[i].color : t.muted.withValues(alpha: 0.3),
                width: i == activeIndex ? 2.5 : 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(players[i].emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '${players[i].name} • ${players[i].score}',
                  style: TextStyle(
                    color: t.text,
                    fontWeight: i == activeIndex ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Banner announcing whose turn it is (pass-and-play party helper).
class TurnBanner extends StatelessWidget {
  final Player player;
  final String action;

  const TurnBanner({super.key, required this.player, required this.action});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [player.color.withValues(alpha: 0.85), player.color.withValues(alpha: 0.55)]),
        borderRadius: t.radius,
      ),
      child: Text(
        '${player.emoji} ${player.name}$action',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }
}

/// Simple themed dialog shell.
class WajihaDialog extends StatelessWidget {
  final String title;
  final String? emoji;
  final List<Widget> children;

  const WajihaDialog({super.key, required this.title, this.emoji, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: t.radius),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: t.text), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
