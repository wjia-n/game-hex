import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'audio.dart';
import 'engine.dart';
import 'hex_theme.dart';
import 'hex_themes.dart';
import 'settings.dart';

/// Hex game screen — Atelier Hex ceramic workshop UI.
/// Engine/rules live in engine.dart; this file is layout, interaction,
/// animation and physical rendering only. The engine owns ALL turn state
/// (this screen only listens); bot turns schedule through the engine's
/// phase timer so every placement animates visibly on the bot's own tray.
class HexGameScreen extends StatefulWidget {
  final bool vsAi;
  final bool restore;
  const HexGameScreen({super.key, required this.vsAi, this.restore = false});

  @override
  State<HexGameScreen> createState() => _HexGameScreenState();
}

class _HexGameScreenState extends State<HexGameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late HexEngine engine;
  final HxSettings _settings = HxSettings.instance;

  late int _humanColor; // vs-AI only; flips if the pie-rule swap happens
  bool _swapSeen = false;
  bool _overHandled = false;
  int _seenMoves = 0;
  bool _overlayPaused = false; // pause via the pause menu
  bool _bgPaused = false; // pause via app backgrounding

  late AnimationController _placeCtrl;
  List<int>? _placeCell;

  DateTime _t0 = DateTime.now();
  Duration _pausedAccum = Duration.zero;
  DateTime? _pauseStart;
  Duration _finalDuration = Duration.zero;

  HxThemeDef get _theme => _settings.theme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _humanColor = _settings.humanColor;
    _t0 = DateTime.now();
    _newEngine();
    if (widget.restore) {
      _restoreSaved();
    } else {
      HxAudio.instance.start();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HxAudio.instance.startGameMusic();
    });
  }

  /// Build a fresh engine wired to the turn director.
  void _newEngine() {
    engine = HexEngine(
        size: _settings.boardSize, pieRuleEnabled: _settings.pieRule);
    if (widget.vsAi) {
      final bots = [false, false];
      bots[1 - _humanColor] = true;
      engine.configure(
          bots: bots, difficulty: _settings.difficulty);
    }
    _seenMoves = engine.moveCount;
    _swapSeen = engine.swapUsed;
    _overHandled = engine.over;
    engine.addListener(_onEngineChanged);
    engine.begin();
  }

  Future<void> _restoreSaved() async {
    final raw = await _settings.loadGame();
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      engine.removeListener(_onEngineChanged);
      engine.dispose();
      engine = HexEngine.fromJson(j['engine'] as Map<String, dynamic>);
      _humanColor = (j['humanColor'] as num).toInt();
      _t0 = DateTime.now()
          .subtract(Duration(milliseconds: (j['elapsedMs'] as num).toInt()));
      _pausedAccum = Duration.zero;
      _pauseStart = null;
      _seenMoves = engine.moveCount;
      _swapSeen = engine.swapUsed;
      _overHandled = false;
      engine.addListener(_onEngineChanged);
      engine.begin();
      if (mounted) setState(() {});
    } catch (_) {
      // Corrupt save: fall back to the fresh engine already installed.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    engine.removeListener(_onEngineChanged);
    engine.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      HxAudio.instance.onAppPaused();
      if (!engine.over && !engine.paused) {
        engine.setPaused(true);
        _bgPaused = true;
        _saveGame();
        if (mounted) setState(() {});
      }
    } else if (state == AppLifecycleState.resumed && mounted) {
      HxAudio.instance.onAppResumed();
      if (_bgPaused && !_overlayPaused && !engine.over) {
        _bgPaused = false;
        engine.setPaused(false);
      }
    }
  }

  Duration get _elapsed {
    var e = DateTime.now().difference(_t0) - _pausedAccum;
    if (_pauseStart != null) e -= DateTime.now().difference(_pauseStart!);
    return e;
  }

  bool get _awaitingSwap =>
      engine.phase == HexPhase.awaitingSwap && !engine.isBot[engine.turn];

  // ---------------- engine events -> audio/animation ----------------

  void _onEngineChanged() {
    if (!mounted) return;
    // New placement: animate it on the board, kiln clack.
    if (engine.moveCount > _seenMoves) {
      _seenMoves = engine.moveCount;
      _placeCell = engine.lastMove;
      _placeCtrl.forward(from: 0.0);
      HxAudio.instance.place();
    }
    // Swap happened (by human or bot): flip the human's color in vs-AI.
    if (engine.swapUsed && !_swapSeen) {
      _swapSeen = true;
      if (widget.vsAi) _humanColor = 1 - _humanColor;
      HxAudio.instance.swap();
    }
    // Game over: tally, sounds, clear the in-progress save.
    if (engine.over && !_overHandled) {
      _overHandled = true;
      _onGameOver();
    }
    setState(() {});
  }

  // ---------------- actions ----------------

  void _onTapCell(int q, int r) {
    if (engine.over || engine.paused || _awaitingSwap) return;
    if (engine.board[q][r] != -1) {
      HxAudio.instance.invalid();
      return;
    }
    if (!engine.humanPlay(q, r)) {
      HxAudio.instance.invalid();
    }
  }

  void _doSwap() {
    if (engine.humanSwap()) {
      _placeCell = null;
      _saveGame();
    }
  }

  void _declineSwap() {
    engine.humanDeclineSwap();
    HxAudio.instance.click();
    _saveGame();
  }

  void _onGameOver() {
    _finalDuration = _elapsed;
    _settings.recordResult(engine.winner ?? 0);
    _settings.clearSave();
    if (widget.vsAi) {
      if (engine.winner == _humanColor) {
        HxAudio.instance.win();
      } else {
        HxAudio.instance.lose();
      }
    } else {
      HxAudio.instance.win();
    }
  }

  void _onUndo() {
    final removed = engine.humanUndo(widget.vsAi ? 2 : 1);
    if (removed > 0) {
      HxAudio.instance.click();
      _placeCell = null;
      _seenMoves = engine.moveCount;
      _saveGame();
    } else {
      HxAudio.instance.invalid();
    }
  }

  void _onRestart() {
    HxAudio.instance.click();
    engine.removeListener(_onEngineChanged);
    engine.dispose();
    _humanColor = _settings.humanColor;
    _newEngine();
    _placeCell = null;
    _t0 = DateTime.now();
    _pausedAccum = Duration.zero;
    _pauseStart = null;
    _overlayPaused = false;
    _bgPaused = false;
    _settings.clearSave();
    HxAudio.instance.start();
    setState(() {});
  }

  void _onPause() {
    if (engine.over || engine.paused) return;
    _overlayPaused = true;
    _pauseStart = DateTime.now();
    engine.setPaused(true);
    HxAudio.instance.click();
    _saveGame();
    setState(() {});
  }

  void _onResume() {
    if (!_overlayPaused) return;
    _overlayPaused = false;
    if (_pauseStart != null) {
      _pausedAccum += DateTime.now().difference(_pauseStart!);
      _pauseStart = null;
    }
    engine.setPaused(false);
    HxAudio.instance.click();
    setState(() {});
  }

  void _onResign() {
    HxAudio.instance.click();
    engine.humanResign(widget.vsAi ? _humanColor : engine.turn);
    _overlayPaused = false;
    _pauseStart = null;
  }

  void _onQuitToMenu() {
    HxAudio.instance.click();
    if (!engine.over) _saveGame(); // keep for "Continue"
    Navigator.of(context).pop();
  }

  Future<void> _saveGame() async {
    if (engine.over) return;
    await _settings.saveGame(jsonEncode({
      'engine': engine.toJson(),
      'vsAi': widget.vsAi,
      'humanColor': _humanColor,
      'elapsedMs': _elapsed.inMilliseconds,
    }));
  }

  void _renamePlayer(int player) {
    final ctrl = TextEditingController(text: _settings.nameOf(player));
    HxAudio.instance.click();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: HxTheme.biscuit,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name this player',
                  style: HxTheme.plaqueTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLength: 16,
                autofocus: true,
                style: HxTheme.body.copyWith(fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel',
                        style: HxTheme.body
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  ClayButton(
                    label: 'Save',
                    fontSize: 16,
                    glazeColor: _theme.glaze(player).$2,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((ok) async {
      if (ok == true) {
        await _settings.setPlayerName(player, ctrl.text);
        HxAudio.instance.click();
        if (mounted) setState(() {});
      }
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WorkbenchBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopPlaque(),
                  _buildTray(0),
                  Expanded(child: _buildBoard()),
                  _buildTray(1),
                  _buildThumbRail(),
                ],
              ),
              if (_awaitingSwap) _buildSwapPrompt(),
              if (engine.paused && !engine.over) _buildPauseOverlay(),
              if (engine.over) _buildVictoryOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPlaque() {
    String status;
    if (engine.over) {
      status = '${_settings.nameOf(engine.winner ?? 0)} wins';
    } else if (_awaitingSwap) {
      status = '${_settings.nameOf(1)} may swap colors!';
    } else if (engine.paused) {
      status = 'Paused';
    } else {
      final name = _settings.nameOf(engine.turn);
      if (engine.phase == HexPhase.aiThinking) {
        status = '$name is thinking…';
      } else if (engine.phase == HexPhase.settling) {
        status = '$name placed a tile';
      } else if (widget.vsAi && engine.turn == _humanColor) {
        status = 'Your move, $name';
      } else {
        status = '$name to move';
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: HxTheme.clayPlaque(radius: 14),
        child: Row(
          children: [
            GlazedHexIcon(
                size: 40,
                player: engine.turn,
                glaze: _theme.glaze(engine.turn)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status,
                      style: HxTheme.plaqueTitle.copyWith(fontSize: 18)),
                  Text(
                    engine.turn == 0
                        ? 'Connect top ⟷ bottom'
                        : 'Connect left ⟷ right',
                    style: HxTheme.body.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: HxTheme.walnutSign(radius: 10),
              child: Text('Move ${engine.moveCount}',
                  style: HxTheme.body.copyWith(
                      color: HxTheme.cream,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  /// Per-side tile tray: each player owns their strip. The active side
  /// raises with a carved highlight; a bot's tray shows "thinking…" with an
  /// animated pulse while the engine schedules its move. Never auto-plays
  /// silently — every placement lands on the board with narration here.
  Widget _buildTray(int player) {
    final active = !engine.over && engine.turn == player;
    final thinking =
        active && engine.phase == HexPhase.aiThinking && engine.isBot[player];
    final isBotSide = engine.isBot[player];
    final name = _settings.nameOf(player);
    final glaze = _theme.glaze(player);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: active
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(glaze.$2, Colors.white, 0.32)!,
                    Color.lerp(glaze.$2, Colors.white, 0.12)!,
                  ],
                ),
                border: Border.all(
                    color: glaze.$1.withValues(alpha: 0.9), width: 2),
                boxShadow: HxTheme.plaqueShadow,
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black.withValues(alpha: 0.22),
                border: Border.all(
                    color: Colors.black.withValues(alpha: 0.35), width: 1.2),
              ),
        child: Row(
          children: [
            thinking
                ? _ThinkingTile(glaze: glaze)
                : GlazedHexIcon(size: 34, player: player, glaze: glaze),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _renamePlayer(player),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: HxTheme.plaqueTitle.copyWith(
                                  fontSize: 16,
                                  color: active
                                      ? HxTheme.carved
                                      : HxTheme.cream
                                          .withValues(alpha: 0.85))),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit,
                            size: 13,
                            color: (active
                                    ? HxTheme.carved
                                    : HxTheme.cream)
                                .withValues(alpha: 0.55)),
                      ],
                    ),
                    Text(
                      thinking
                          ? 'thinking…'
                          : active
                              ? (isBotSide
                                  ? 'placing a tile…'
                                  : (engine.phase == HexPhase.awaitingSwap
                                      ? 'swap or play!'
                                      : 'place a tile'))
                              : '${engine.placedCount(player)} tiles',
                      style: HxTheme.body.copyWith(
                          fontSize: 12.5,
                          fontStyle: thinking || active
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: (active
                                  ? HxTheme.carved
                                  : HxTheme.cream)
                              .withValues(alpha: active ? 0.85 : 0.6)),
                    ),
                  ],
                ),
              ),
            ),
            if (isBotSide)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: Text('BOT',
                    style: HxTheme.body.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: HxTheme.cream.withValues(alpha: 0.85))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return GestureDetector(
          onTapUp: (d) {
            final painter = _BoardPainter(
                engine: engine,
                theme: _theme,
                tileStyle: _settings.tileStyle);
            final cell = painter.cellAt(
                d.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight));
            if (cell != null) _onTapCell(cell[0], cell[1]);
          },
          child: AnimatedBuilder(
            animation: _placeCtrl,
            builder: (context, _) => CustomPaint(
              painter: _BoardPainter(
                engine: engine,
                theme: _theme,
                tileStyle: _settings.tileStyle,
                placeCell: _placeCell,
                placeT: _placeCtrl.value,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbRail() {
    final undoEnabled = engine.phase == HexPhase.awaitingMove &&
        engine.history.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: HxTheme.walnutSign(radius: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TokenButton(icon: Icons.pause, onTap: _onPause),
            TokenButton(icon: Icons.refresh, onTap: _onRestart),
            TokenButton(
                icon: Icons.undo, onTap: _onUndo, enabled: undoEnabled),
          ],
        ),
      ),
    );
  }

  Widget _dim() => Container(color: Colors.black.withValues(alpha: 0.55));

  Widget _buildSwapPrompt() {
    return Stack(
      children: [
        _dim(),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: HxTheme.clayPlaque(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlazedHexIcon(
                          size: 44,
                          player: 0,
                          glaze: _theme.glaze(0)),
                      const SizedBox(width: 8),
                      const Icon(Icons.swap_horiz,
                          size: 30, color: HxTheme.carved),
                      const SizedBox(width: 8),
                      GlazedHexIcon(
                          size: 44,
                          player: 1,
                          glaze: _theme.glaze(1)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Pie rule — swap?',
                      style: HxTheme.plaqueTitle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    '${_settings.nameOf(0)} opened strong. As ${_settings.nameOf(1)}, you may swap colors and steal that tile — or play on.',
                    style: HxTheme.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ClayButton(
                      label: 'Swap tiles',
                      glazeColor: _theme.glaze(1).$2,
                      onTap: _doSwap),
                  const SizedBox(height: 10),
                  ClayButton(label: 'Keep playing', onTap: _declineSwap),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPauseOverlay() {
    return Stack(
      children: [
        _dim(),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  decoration: HxTheme.walnutSign(),
                  child:
                      Text('Paused', style: HxTheme.title(30, HxTheme.cream)),
                ),
                const SizedBox(height: 22),
                ClayButton(label: 'Resume', onTap: _onResume),
                const SizedBox(height: 12),
                ClayButton(label: 'Restart', onTap: _onRestart),
                const SizedBox(height: 12),
                ClayButton(label: 'Resign', onTap: _onResign),
                const SizedBox(height: 12),
                ClayButton(label: 'Quit to menu', onTap: _onQuitToMenu),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVictoryOverlay() {
    final w = engine.winner ?? 0;
    final wName = _settings.nameOf(w);
    final title = engine.resigned ? '$wName wins — rival resigned' : '$wName wins!';
    return Stack(
      children: [
        _dim(),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Winner's tile on a walnut pedestal.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 22),
                  decoration: HxTheme.walnutSign(radius: 18),
                  child: GlazedHexIcon(
                      size: 110, player: w, glaze: _theme.glaze(w)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF7EBD9),
                        HxTheme.cream,
                        Color(0xFFDCC9AC)
                      ],
                    ),
                    boxShadow: HxTheme.plaqueShadow,
                  ),
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: HxTheme.title(26, HxTheme.carved)),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: HxTheme.walnutSign(radius: 14),
                  child: Column(
                    children: [
                      _tallyRow('Moves', '${engine.moveCount}'),
                      _tallyRow('Duration', _fmt(_finalDuration)),
                      _tallyRow('Board', '${engine.size} × ${engine.size}'),
                      _tallyRow('Pie rule',
                          engine.swapUsed ? 'Swap used' : 'No swap'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ClayButton(
                    label: 'Play again',
                    glazeColor: _theme.glaze(w).$2,
                    onTap: _onRestart),
                const SizedBox(height: 10),
                ClayButton(label: 'Main menu', onTap: _onQuitToMenu),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tallyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: HxTheme.body
                  .copyWith(color: HxTheme.cream.withValues(alpha: 0.8))),
          Text(value,
              style: HxTheme.body.copyWith(
                  color: HxTheme.cream, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Pulsing tile shown on a bot's tray while the engine schedules its move.
class _ThinkingTile extends StatefulWidget {
  final (Color, Color, Color) glaze;
  const _ThinkingTile({required this.glaze});

  @override
  State<_ThinkingTile> createState() => _ThinkingTileState();
}

class _ThinkingTileState extends State<_ThinkingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Transform.scale(
        scale: 1.0 + _c.value * 0.12,
        child: Opacity(
          opacity: 0.75 + _c.value * 0.25,
          child: GlazedHexIcon(size: 34, player: 0, glaze: widget.glaze),
        ),
      ),
    );
  }
}

// ==================== BOARD PAINTER ====================
/// Pseudo-3D ceramic board: walnut tray, mortised wells, extruded glazed
/// tiles with bevels, specular highlights and contact shadows, rendered in
/// the active theme's palette and tile-glaze style.
class _BoardPainter extends CustomPainter {
  final HexEngine engine;
  final HxThemeDef theme;
  final int tileStyle;
  final List<int>? placeCell;
  final double placeT; // 0..1 weighted-settle progress

  late int n;
  double _s = 18;
  Offset _origin = Offset.zero;

  _BoardPainter(
      {required this.engine,
      required this.theme,
      required this.tileStyle,
      this.placeCell,
      this.placeT = 1.0}) {
    n = engine.size;
  }

  Offset centerOf(int q, int r) => Offset(
        _origin.dx + _s * sqrt(3) * (q + r / 2),
        _origin.dy + _s * 1.5 * r,
      );

  void layout(Size size) {
    const pad = 12.0;
    _s = min(
      (size.width - pad * 2) / ((1.5 * n - 0.5) * sqrt(3)),
      (size.height - pad * 2) / (1.5 * n + 0.5 + 3.2),
    );
    final totalW = (1.5 * n - 0.5) * sqrt(3) * _s;
    final totalH = (1.5 * n + 0.5) * _s;
    _origin = Offset(
      (size.width - totalW) / 2 + sqrt(3) / 2 * _s,
      (size.height - totalH) / 2 + _s,
    );
  }

  List<int>? cellAt(Offset p, Size size) {
    layout(size);
    var bestD = 1e9;
    List<int>? best;
    for (int q = 0; q < n; q++) {
      for (int r = 0; r < n; r++) {
        final d = (p - centerOf(q, r)).distance;
        if (d < bestD) {
          bestD = d;
          best = [q, r];
        }
      }
    }
    return bestD <= _s * 1.1 ? best : null;
  }

  Path hexPath(Offset c, double r) {
    final p = Path();
    for (int i = 0; i < 6; i++) {
      final a = (60 * i - 30) * pi / 180;
      final v = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        p.moveTo(v.dx, v.dy);
      } else {
        p.lineTo(v.dx, v.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    layout(size);
    _paintTray(canvas);
    _paintCells(canvas);
    _paintWinGroove(canvas);
  }

  void _paintTray(Canvas canvas) {
    final cT = centerOf(0, 0);
    final cR = centerOf(n - 1, 0);
    final cB = centerOf(n - 1, n - 1);
    final cL = centerOf(0, n - 1);
    final mid = (cT + cR + cB + cL) / 4;
    Offset push(Offset c, double m) {
      final d = c - mid;
      final len = d.distance;
      if (len < 1e-6) return c;
      return c + d / len * m;
    }

    final tray = [
      push(cT, _s * 2.0),
      push(cR, _s * 2.0),
      push(cB, _s * 2.0),
      push(cL, _s * 2.0)
    ];
    final field = [
      push(cT, _s * 0.7),
      push(cR, _s * 0.7),
      push(cB, _s * 0.7),
      push(cL, _s * 0.7)
    ];

    Path poly(List<Offset> pts) {
      final p = Path();
      p.moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      p.close();
      return p;
    }

    final trayPath = poly(tray);
    final bounds = trayPath.getBounds();

    // Tray body: oiled walnut with kiln-light gradient.
    canvas.drawPath(
        trayPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(theme.walnut, Colors.white, 0.12)!,
              theme.walnut,
              theme.walnutDeep
            ],
          ).createShader(bounds)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    // Tray drop shadow on the workbench.
    canvas.drawPath(
        trayPath,
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10);

    // Bevel: light on upper-left edges, dark on lower-right.
    final bevelLight = Paint()
      ..color = const Color(0x3AFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, _s * 0.12)
      ..strokeCap = StrokeCap.round;
    final bevelDark = Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, _s * 0.12)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tray[3], tray[0], bevelLight);
    canvas.drawLine(tray[0], tray[1], bevelLight);
    canvas.drawLine(tray[1], tray[2], bevelDark);
    canvas.drawLine(tray[2], tray[3], bevelDark);

    // Corner dowels.
    for (final v in tray) {
      canvas.drawCircle(
          v,
          _s * 0.42,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [
                Color.lerp(theme.walnut, Colors.white, 0.18)!,
                theme.walnutDeep
              ],
            ).createShader(Rect.fromCircle(center: v, radius: _s * 0.42)));
    }

    // Mortised field.
    final fieldPath = poly(field);
    canvas.drawPath(
        fieldPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(theme.walnutDeep, Colors.black, 0.25)!,
              Color.lerp(theme.walnutDeep, Colors.black, 0.5)!,
            ],
          ).createShader(fieldPath.getBounds()));
    // Inner shadow lip of the field.
    canvas.drawPath(
        fieldPath,
        Paint()
          ..color = const Color(0x88000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2, _s * 0.16));

    // Glaze-inlay edge strips: terracotta top/bottom, indigo left/right.
    void inlay(Offset a, Offset b, Color color) {
      final dir = (mid - ((a + b) / 2));
      final len = dir.distance;
      final off = len < 1e-6 ? Offset.zero : dir / len * _s * 0.55;
      canvas.drawLine(
          a + off,
          b + off,
          Paint()
            ..color = color
            ..strokeWidth = max(2.5, _s * 0.3)
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(
          a + off + const Offset(0, 1),
          b + off + const Offset(0, 1),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..strokeWidth = max(1, _s * 0.08)
            ..strokeCap = StrokeCap.round);
    }

    inlay(field[0], field[1], theme.terra); // top
    inlay(field[3], field[2], theme.terra); // bottom
    inlay(field[0], field[3], theme.indigo); // left
    inlay(field[1], field[2], theme.indigo); // right
  }

  void _paintCells(Canvas canvas) {
    final winSet = <String>{};
    if (engine.winPath != null) {
      for (final c in engine.winPath!) {
        winSet.add('${c[0]},${c[1]}');
      }
    }
    for (int q = 0; q < n; q++) {
      for (int r = 0; r < n; r++) {
        final c = centerOf(q, r);
        final v = engine.board[q][r];
        if (v == -1) {
          _paintWell(canvas, c);
        } else {
          var scale = 1.0;
          var dy = 0.0;
          if (placeCell != null &&
              placeCell![0] == q &&
              placeCell![1] == r &&
              placeT < 1.0) {
            // Weighted settle: drop in with a soft overshoot.
            final e = Curves.elasticOut.transform(placeT.clamp(0.0, 1.0));
            scale = max(0.05, e);
            dy = -_s * 1.6 * (1 - placeT) * (1 - placeT);
          }
          _paintTile(canvas, c + Offset(0, dy), _s * 0.94, v, scale, q, r,
              inWin: winSet.contains('$q,$r'));
        }
      }
    }
  }

  /// Shallow mortised hex recess (empty cell).
  void _paintWell(Canvas canvas, Offset c) {
    final r = _s * 0.92;
    final path = hexPath(c, r);
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(theme.walnutDeep, Colors.black, 0.35)!,
              Color.lerp(theme.walnutDeep, Colors.black, 0.6)!,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(
        path,
        Paint()
          ..color = theme.carved
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, _s * 0.07));
    // Light catching the lower-right inner wall (kiln light from upper-left).
    final corners = List.generate(
        6,
        (i) => Offset(c.dx + r * cos((60 * i - 30) * pi / 180),
            c.dy + r * sin((60 * i - 30) * pi / 180)));
    final lip = Paint()
      ..color = theme.cream.withValues(alpha: 0.10)
      ..strokeWidth = max(1, _s * 0.06)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(corners[0], corners[1], lip);
    canvas.drawLine(corners[1], corners[2], lip);
  }

  /// Chunky glazed hex tile: contact shadow, extruded body, pillowed glaze
  /// top with specular highlight and bevel, in the active tile-glaze style.
  void _paintTile(Canvas canvas, Offset c, double r, int player, double scale,
      int q, int rr,
      {bool inWin = false}) {
    var (hi, mid, lo) = theme.glaze(player);
    // Matte bisque: flatten the glaze response.
    if (tileStyle == 2) {
      hi = Color.lerp(hi, mid, 0.55)!;
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    canvas.translate(-c.dx, -c.dy);

    // Warm contact shadow on the wood.
    canvas.save();
    canvas.translate(2.5, 5);
    canvas.drawPath(
        hexPath(c, r),
        Paint()
          ..color = const Color(0x55000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.restore();

    // Extruded body (side walls catching low light).
    canvas.save();
    canvas.translate(0, max(1.5, _s * 0.10));
    canvas.drawPath(hexPath(c, r), Paint()..color = lo);
    canvas.restore();

    // Dipped two-tone: darker glaze pooling on the lower half.
    if (tileStyle == 6) {
      canvas.save();
      canvas.clipPath(hexPath(c, r * 0.97));
      canvas.drawRect(
          Rect.fromCenter(
              center: c + Offset(0, r * 0.5), width: r * 2, height: r),
          Paint()..color = lo.withValues(alpha: 0.55));
      canvas.restore();
    }

    // Glazed top face: pooling highlight upper-left.
    final top = hexPath(c, r * 0.97);
    final specularAlpha = tileStyle == 2 ? 0.16 : 0.38;
    canvas.drawPath(
        top,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.38, -0.45),
            radius: 1.15,
            colors: [hi, mid, lo],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    // Bevel rim.
    canvas.drawPath(
        top,
        Paint()
          ..color = lo
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, _s * 0.07));

    // ---- glaze style variations (all deterministic per cell) ----
    final seed = Random(q * 92821 + rr * 1237 + tileStyle * 7919 + player * 131);
    if (tileStyle == 1 || tileStyle == 9) {
      // Speckled stoneware / salt glaze: kiln speckles.
      final count = tileStyle == 9 ? 26 : 12;
      for (int i = 0; i < count; i++) {
        final a = seed.nextDouble() * 2 * pi;
        final d = seed.nextDouble() * r * 0.7;
        final dot = c + Offset(cos(a) * d, sin(a) * d);
        canvas.drawCircle(
            dot,
            max(0.8, r * 0.045 * seed.nextDouble() + r * 0.02),
            Paint()
              ..color = (tileStyle == 9 ? Colors.white : lo)
                  .withValues(alpha: tileStyle == 9 ? 0.35 : 0.5));
      }
    } else if (tileStyle == 5) {
      // Iron spots: dark metallic flecks.
      for (int i = 0; i < 9; i++) {
        final a = seed.nextDouble() * 2 * pi;
        final d = seed.nextDouble() * r * 0.72;
        canvas.drawCircle(
            c + Offset(cos(a) * d, sin(a) * d),
            max(0.8, r * 0.06),
            Paint()..color = const Color(0xFF2E1A0E).withValues(alpha: 0.65));
      }
    } else if (tileStyle == 4) {
      // Raku crackle: thin dark fissures.
      final crack = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = max(0.8, r * 0.02);
      for (int i = 0; i < 4; i++) {
        final a0 = seed.nextDouble() * 2 * pi;
        final p0 = c + Offset(cos(a0), sin(a0)) * r * 0.15;
        final p1 = c + Offset(cos(a0 + 0.7), sin(a0 + 0.7)) * r * 0.55;
        final p2 = c + Offset(cos(a0 + 1.6), sin(a0 + 1.6)) * r * 0.85;
        final path = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy);
        canvas.drawPath(path, crack);
      }
    } else if (tileStyle == 7) {
      // Ash dusted: pale kiln ash settling on the upper face.
      for (int i = 0; i < 14; i++) {
        final a = seed.nextDouble() * 2 * pi;
        final d = seed.nextDouble() * r * 0.7;
        final dot = c + Offset(cos(a) * d, sin(a) * d - r * 0.12);
        canvas.drawCircle(
            dot,
            max(0.8, r * 0.05),
            Paint()..color = Colors.white.withValues(alpha: 0.22));
      }
    }
    if (tileStyle == 3 || tileStyle == 8) {
      // Ring inlay / carved groove: inner hex detail.
      canvas.drawPath(
          hexPath(c, r * 0.62),
          Paint()
            ..color = (tileStyle == 3
                    ? theme.cream
                    : const Color(0xFF000000))
                .withValues(alpha: tileStyle == 3 ? 0.55 : 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, r * 0.05));
      if (tileStyle == 8) {
        canvas.save();
        canvas.translate(0, 1.2);
        canvas.drawPath(
            hexPath(c, r * 0.62),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.18)
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(0.8, r * 0.025));
        canvas.restore();
      }
    }

    // Specular pill (glaze pooling).
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(-r * 0.24, -r * 0.30),
            width: r * 0.52,
            height: r * 0.26),
        Paint()..color = Colors.white.withValues(alpha: specularAlpha));
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(r * 0.30, r * 0.34),
            width: r * 0.30,
            height: r * 0.14),
        Paint()..color = Colors.white.withValues(alpha: specularAlpha * 0.3));

    canvas.restore();
  }

  /// Carved groove ring around winning tiles (never a neon glow).
  void _paintWinGroove(Canvas canvas) {
    if (engine.winPath == null) return;
    for (final cell in engine.winPath!) {
      final c = centerOf(cell[0], cell[1]);
      final path = hexPath(c, _s * 0.99);
      canvas.drawPath(
          path,
          Paint()
            ..color = theme.carved.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.5, _s * 0.16));
      canvas.save();
      canvas.translate(0, 1.5);
      canvas.drawPath(
          path,
          Paint()
            ..color = theme.cream.withValues(alpha: 0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1, _s * 0.06));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
