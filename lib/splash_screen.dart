import 'package:flutter/material.dart';

import 'audio.dart';
import 'hex_theme.dart';
import 'main.dart';

/// Launch splash: game logo + name, animated loading line, credits.
/// (Single splash only — no separate company moment.)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    final audio = HxAudio.instance;
    audio.prewarm();
    audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainMenu()),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E1410),
      body: _GameSplash(),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  const _GameSplash();

  @override
  Widget build(BuildContext context) {
    return WorkbenchBackdrop(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: HxTheme.terracotta, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/hex_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('HEX', style: HxTheme.title(58, HxTheme.terracotta)),
            const SizedBox(height: 6),
            Text(
              'THE CERAMIC CONNECTION GAME',
              style: HxTheme.body.copyWith(
                fontSize: 13,
                letterSpacing: 2.5,
                color: HxTheme.carved.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            const _LoadingLine(),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: HxTheme.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: HxTheme.carved,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingLine extends StatefulWidget {
  const _LoadingLine();

  @override
  State<_LoadingLine> createState() => _LoadingLineState();
}

class _LoadingLineState extends State<_LoadingLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Column(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(
                    color: HxTheme.terracotta.withValues(alpha: 0.5)),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _c.value.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [HxTheme.terracottaHi, HxTheme.terracotta],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _c.value < 1 ? 'Firing the kiln…' : 'Ready!',
              style: HxTheme.body.copyWith(
                fontSize: 13,
                color: HxTheme.carved.withValues(alpha: 0.75),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
