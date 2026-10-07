import 'package:flutter/material.dart';
import '../audio/sfx.dart';
import '../iap/tip_jar.dart';
import '../marketing/cross_promo.dart';
import '../players/player.dart';
import '../theme/game_theme.dart';
import 'bits.dart';

/// Callbacks the shell hands to the game screen.
class GameCallbacks {
  /// Call when the match ends.
  final void Function({Player? winner, String? headline, String? subline}) finish;

  /// Call after mutating [Player.score] so the HUD refreshes.
  final void Function() refreshHud;

  /// Tell the shell whose turn it is (highlights their score chip).
  final void Function(int index) setActivePlayer;

  const GameCallbacks({required this.finish, required this.refreshHud, required this.setActivePlayer});
}

enum _Stage { splash, home, setup, playing }

/// The complete app wrapper every game uses: splash, home, player setup,
/// pause menu, themes, tip jar, cross-promo and game-over flow.
class GameShell extends StatefulWidget {
  final String title;
  final String tagline;
  final String emoji;
  final String howToPlay;
  final String slug;
  final List<int> playerOptions;
  final bool supportsBots;
  final Widget Function(BuildContext context, List<Player> players, GameCallbacks callbacks) gameBuilder;

  const GameShell({
    super.key,
    required this.title,
    required this.tagline,
    required this.emoji,
    required this.howToPlay,
    required this.slug,
    required this.gameBuilder,
    this.playerOptions = const [1, 2],
    this.supportsBots = true,
  });

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final ThemeController _themes = ThemeController();
  _Stage _stage = _Stage.splash;
  List<Player> _players = [];
  int _gameKey = 0;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _themes.load();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _stage = _Stage.home);
    });
  }

  void _startSetup() {
    Sfx.click();
    setState(() => _stage = _Stage.setup);
  }

  void _beginGame(List<Player> players) {
    _players = players;
    _gameKey++;
    _activeIndex = 0;
    setState(() => _Stage.playing);
  }

  void _onGameOver({Player? winner, String? headline, String? subline}) {
    Sfx.win();
    final t = _themes.theme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WajihaDialog(
        emoji: winner != null ? winner.emoji : '🎉',
        title: headline ?? (winner != null ? '${winner.name} wins!' : 'Game over!'),
        children: [
          if (subline != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(subline, textAlign: TextAlign.center, style: TextStyle(color: t.muted)),
            ),
          if (winner == null && _players.length > 1) _finalScores(t),
          const SizedBox(height: 8),
          WajihaButton(label: 'Rematch', emoji: '🔁', onTap: () {
            Navigator.pop(context);
            _beginGame(_players.map((p) => PlayerPresets.make(_players.indexOf(p), isBot: p.isBot)).toList());
          }),
          const SizedBox(height: 10),
          WajihaButton(label: 'Share', emoji: '📣', primary: false, onTap: () => CrossPromo.shareGame(widget.slug, widget.title)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _stage = _Stage.home);
            },
            child: Text('Back to menu', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _finalScores(GameTheme t) {
    final ranked = [..._players]..sort((a, b) => b.score.compareTo(a.score));
    return Column(
      children: [
        for (final p in ranked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(p.name, style: TextStyle(color: t.text, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${p.score} pts', style: TextStyle(color: t.muted, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showThemes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: _themes.theme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 48, height: 5, decoration: BoxDecoration(color: _themes.theme.muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 12),
            Text('🎨 Pick your vibe', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _themes.theme.text)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemCount: GameThemes.all.length,
              itemBuilder: (_, i) {
                final th = GameThemes.all[i];
                final active = th.id == _themes.theme.id;
                return GestureDetector(
                  onTap: () {
                    Sfx.tap();
                    _themes.setTheme(th);
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [th.primary, th.secondary]),
                          borderRadius: BorderRadius.circular(18),
                          border: active ? Border.all(color: th.text, width: 3) : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(th.emoji, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(height: 4),
                      Text(th.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: _themes.theme.muted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHowTo() {
    showDialog(
      context: context,
      builder: (_) => WajihaDialog(
        emoji: '❓', title: 'How to play',
        children: [
          Text(widget.howToPlay, style: TextStyle(color: _themes.theme.muted, height: 1.6)),
          const SizedBox(height: 16),
          WajihaButton(label: 'Got it!', onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  void _showTipJar() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => const TipJarSheet());
  }

  void _showMoreGames() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => MoreGamesSheet(currentSlug: widget.slug));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themes,
      builder: (context, _) => MaterialApp(
        title: widget.title,
        debugShowCheckedModeBanner: false,
        theme: _themes.theme.materialTheme,
        home: ThemeScope(
          controller: _themes,
          child: switch (_stage) {
            _Stage.splash => _splash(),
            _Stage.home => _home(),
            _Stage.setup => _PlayerSetup(
                options: widget.playerOptions,
                supportsBots: widget.supportsBots,
                onStart: _beginGame,
                onBack: () => setState(() => _Stage.home),
              ),
            _Stage.playing => _gameScreen(),
          },
        ),
      ),
    );
  }

  Widget _splash() {
    final t = _themes.theme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: t.headerGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.15),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (_, v, __) => Transform.scale(scale: v, child: Text(widget.emoji, style: const TextStyle(fontSize: 90))),
              ),
              const SizedBox(height: 16),
              Text(widget.title,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('a Wajiha fun game 💛', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _home() {
    final t = _themes.theme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [t.background, t.surface], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 48),
                Text(widget.emoji, style: const TextStyle(fontSize: 84)),
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (b) => t.headerGradient.createShader(b),
                  child: Text(widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(widget.tagline, textAlign: TextAlign.center,
                      style: TextStyle(color: t.muted, fontSize: 16, height: 1.5)),
                ),
                const SizedBox(height: 32),
                WajihaButton(label: 'Play', emoji: '▶️', onTap: _startSetup),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAction(emoji: '❓', label: 'How to', onTap: _showHowTo),
                    const SizedBox(width: 18),
                    CircleAction(emoji: '🎨', label: 'Themes', onTap: _showThemes),
                    const SizedBox(width: 18),
                    CircleAction(emoji: '☕', label: 'Tip jar', onTap: _showTipJar),
                    const SizedBox(width: 18),
                    CircleAction(emoji: '🎮', label: 'More', onTap: _showMoreGames),
                  ],
                ),
                const SizedBox(height: 28),
                PromoBanner(currentSlug: widget.slug),
                const SizedBox(height: 24),
                Text('Made with 💛 by Wajiha • 100% free forever',
                    style: TextStyle(color: t.muted.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameScreen() {
    final t = _themes.theme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.pause_rounded, color: t.text),
          onPressed: _showPause,
        ),
        title: Text(widget.title, style: TextStyle(color: t.text, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(icon: Text('🎮', style: const TextStyle(fontSize: 22)), onPressed: _showMoreGames),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_players.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ScoreChips(players: _players, activeIndex: _activeIndex),
              ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_gameKey),
                child: Builder(
                  builder: (ctx) => widget.gameBuilder(
                    ctx,
                    _players,
                    GameCallbacks(
                      finish: _onGameOver,
                      refreshHud: () => setState(() {}),
                      setActivePlayer: (i) => setState(() => _activeIndex = i),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPause() {
    Sfx.tap();
    showDialog(
      context: context,
      builder: (_) => WajihaDialog(
        emoji: '⏸️', title: 'Paused',
        children: [
          WajihaButton(label: 'Resume', emoji: '▶️', onTap: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          WajihaButton(label: 'Restart', emoji: '🔁', primary: false, onTap: () {
            Navigator.pop(context);
            _beginGame(_players.map((p) => PlayerPresets.make(_players.indexOf(p), isBot: p.isBot)).toList());
          }),
          const SizedBox(height: 10),
          WajihaButton(label: 'How to play', emoji: '❓', primary: false, onTap: () {
            Navigator.pop(context);
            _showHowTo();
          }),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _stage = _Stage.home);
            },
            child: Text('Quit to menu', style: TextStyle(color: _themes.theme.muted, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Player-count + bot setup screen (local pass-and-play party setup).
class _PlayerSetup extends StatefulWidget {
  final List<int> options;
  final bool supportsBots;
  final void Function(List<Player>) onStart;
  final VoidCallback onBack;

  const _PlayerSetup({required this.options, required this.supportsBots, required this.onStart, required this.onBack});

  @override
  State<_PlayerSetup> createState() => _PlayerSetupState();
}

class _PlayerSetupState extends State<_PlayerSetup> {
  late int _count;
  late int _seats;
  late List<bool> _bots;
  int _shuffle = 0;

  void _configure(int c) {
    _count = c;
    if (c == 1 && widget.supportsBots) {
      // solo-vs-bot: one human seat plus one bot seat
      _seats = 2;
      _bots = [false, true];
    } else {
      _seats = c;
      _bots = List.filled(c, false);
    }
  }

  @override
  void initState() {
    super.initState();
    _configure(widget.options.first);
  }

  void _setCount(int c) {
    setState(() => _configure(c));
    Sfx.tap();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
          leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: t.text),
              onPressed: widget.onBack)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Who\'s playing?', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: t.text)),
              const SizedBox(height: 6),
              Text('Pass-and-play on this device. No internet needed! 📱',
                  style: TextStyle(color: t.muted)),
              const SizedBox(height: 20),
              Text('PLAYERS', style: TextStyle(color: t.muted, fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  for (final o in widget.options)
                    GestureDetector(
                      onTap: () => _setCount(o),
                      child: Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(
                          gradient: o == _count ? t.headerGradient : null,
                          color: o == _count ? null : t.surface,
                          borderRadius: t.radius,
                          border: Border.all(color: o == _count ? Colors.transparent : t.muted.withValues(alpha: 0.4), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text('$o', style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: o == _count ? (t.dark ? Colors.black : Colors.white) : t.text)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('SQUAD', style: TextStyle(color: t.muted, fontWeight: FontWeight.w800, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _shuffle++),
                    child: Text('🔀 shuffle', style: TextStyle(color: t.primary, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _seats,
                  itemBuilder: (_, i) {
                    final p = PlayerPresets.make(i + _shuffle * 7, isBot: _bots[i]);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: t.surface, borderRadius: t.radius,
                          border: Border.all(color: p.color.withValues(alpha: 0.5), width: 2)),
                      child: Row(
                        children: [
                          Text(p.emoji, style: const TextStyle(fontSize: 30)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 16)),
                                Text(_bots[i] ? '🤖 Bot opponent' : '🙂 Human (this device)',
                                    style: TextStyle(color: t.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (widget.supportsBots && i > 0)
                            Switch(
                              value: _bots[i],
                              activeThumbColor: t.primary,
                              onChanged: (v) => setState(() => _bots[i] = v),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Center(child: WajihaButton(label: 'Start game', emoji: '🚀', onTap: () {
                Sfx.click();
                widget.onStart([
                  for (int i = 0; i < _seats; i++) PlayerPresets.make(i + _shuffle * 7, isBot: _bots[i]),
                ]);
              })),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
