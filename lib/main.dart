import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const HexApp());

class HexApp extends StatelessWidget {
  const HexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Hex',
      tagline: 'Two rivals. One board. Zero draws. Build your bridge! ⬡',
      emoji: '⬡',
      slug: 'hex',
      howToPlay:
          '• Tap empty hexes to claim them with your color.\n• 🔴 Connect TOP to BOTTOM — or 🔵 connect LEFT to RIGHT.\n• Every game has a winner. No draws. No mercy.\n• Block their bridge while building yours. Sneaky wins! 🏆',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => HexScreen(players: players, callbacks: cb),
    );
  }
}
