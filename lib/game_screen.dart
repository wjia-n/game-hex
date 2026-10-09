import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'audio.dart';
import 'engine.dart';
import 'hex_theme.dart';
import 'settings.dart';

/// Hex game screen — Atelier Hex ceramic workshop UI.
/// Engine/rules live in engine.dart; this file is layout, interaction,
/// animation and physical rendering only.
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
  final HexAI _ai = HexAI();
  final HxSettings _settings = HxSettings.instance;

  late int _humanColor; // vs-AI only; flips if the pie-rule swap happens
  bool paused = false;
  bool _aiThinking = false;
  int _aiGen = 0;

  late AnimationController _placeCtrl;
  List<int>? _placeCell;

  DateTime _t0 = DateTime.now();
  Duration _pausedAccum = Duration.zero;
  DateTime? _pauseStart;
  Duration _finalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _humanColor = _settings.humanColor;
    // Always have a valid engine for the first build; restore swaps it in.
    engine = HexEngine(size: _settings.boardSize, pieRuleEnabled: _settings.pieRule);
    _t0 = DateTime.now();
    if (widget.restore) {
      _restoreSaved();
    } else {
      HxAudio.instance.start();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HxAudio.instance.playMusic('audio/music_game.wav');
      _maybeAi();
    });
  }

  Future<void> _restoreSaved() async {
    final raw = await _settings.loadGame();
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      engine = HexEngine.fromJson(j['engine'] as Map<String, dynamic>);
      _humanColor = (j['humanColor'] as num).toInt();
      _t0 = DateTime.now()
          .subtract(Duration(milliseconds: (j['elapsedMs'] as num).toInt()));
      _pausedAccum = Duration.zero;
      _pauseStart = null;
      if (mounted) setState(() {});
      _maybeAi();
    } catch (_) {
      // Corrupt save: fall back to the fresh engine already installed.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _placeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      HxAudio.instance.stopMusic();
      if (!engine.over && !paused) _onPause(quiet: true);
    } else if (state == AppLifecycleState.resumed && mounted) {
      if (!engine.over) HxAudio.instance.playMusic('audio/music_game.wav');
    }
  }

  Duration get _elapsed {
    var e = DateTime.now().difference(_t0) - _pausedAccum;
    if (_pauseStart != null) e -= DateTime.now().difference(_pauseStart!);
    return e;
  }

  bool get _awaitingSwap =>
      engine.canSwap &&
      engine.turn == 1 &&
      !engine.over &&
      !paused &&
      (widget.vsAi ? _humanColor == 1 : true);

  bool get _humanTurn =>
      !widget.vsAi || (engine.turn == _humanColor && !_aiThinking);

  // ---------------- actions ----------------

  void _onTapCell(int q, int r) {
    if (engine.over || paused || _awaitingSwap) return;
    if (widget.vsAi && !_humanTurn) return;
    if (engine.board[q][r] != -1) {
      HxAudio.instance.invalid();
      return;
    }
    _applyMove(q, r);
  }

  bool _applyMove(int q, int r) {
    if (!engine.play(q, r)) {
      HxAudio.instance.invalid();
      return false;
    }
    _placeCell = [q, r];
    _placeCtrl.forward(from: 0.0);
    HxAudio.instance.place();
    if (engine.over) {
      _onGameOver();
    } else {
      _saveGame();
    }
    setState(() {});
    _maybeAi();
    return true;
  }

  void _doSwap({required bool byAi}) {
    if (!engine.swap()) return;
    _humanColor = 1 - _humanColor;
    HxAudio.instance.swap();
    _placeCell = null;
    _saveGame();
    setState(() {});
    _maybeAi();
  }

  void _declineSwap() {
    engine.declineSwap();
    HxAudio.instance.click();
    _saveGame();
    setState(() {});
    _maybeAi();
  }

  void _maybeAi() {
    if (!widget.vsAi || engine.over || paused || !mounted) return;
    if (engine.turn == _humanColor || _aiThinking) return;
    _aiThinking = true;
    final gen = ++_aiGen;
    final aiColor = 1 - _humanColor;
    final swapTurn = engine.canSwap;
    Future.delayed(Duration(milliseconds: swapTurn ? 900 : 650), () {
      if (!mounted || gen != _aiGen || engine.over || paused) {
        _aiThinking = false;
        return;
      }
      if (widget.vsAi && engine.turn != _humanColor) {
        if (engine.canSwap) {
          // AI holds the swap option: take strong openings.
          if (_ai.shouldSwap(engine, engine.history.first)) {
            _aiThinking = false;
            _doSwap(byAi: true);
            return;
          }
          engine.declineSwap();
          setState(() {});
        } else {
          final mv = _ai.chooseMove(engine, aiColor, _settings.difficulty);
          _applyMove(mv[0], mv[1]);
        }
      }
      _aiThinking = false;
      if (mounted) _maybeAi();
    });
  }

  void _onGameOver() {
    _finalDuration = _elapsed;
    _settings.recordResult(engine.winner ?? 0);
    _settings.clearSave();
    _aiGen++; // cancel any pending AI move
    _aiThinking = false;
    if (widget.vsAi) {
      if (engine.winner == _humanColor) {
        HxAudio.instance.win();
      } else {
        HxAudio.instance.lose();
      }
    } else {
      HxAudio.instance.win();
    }
    setState(() {});
  }

  void _onUndo() {
    if (engine.over ||
        paused ||
        _aiThinking ||
        engine.swapAvailable ||
        engine.history.isEmpty) {
      HxAudio.instance.invalid();
      return;
    }
    final removed = engine.undo(widget.vsAi ? 2 : 1);
    if (removed > 0) {
      HxAudio.instance.click();
      _placeCell = null;
      _saveGame();
      setState(() {});
    } else {
      HxAudio.instance.invalid();
    }
  }

  void _onRestart() {
    HxAudio.instance.click();
    _aiGen++;
    _aiThinking = false;
    _humanColor = _settings.humanColor;
    engine = HexEngine(
        size: _settings.boardSize, pieRuleEnabled: _settings.pieRule);
    _placeCell = null;
    _t0 = DateTime.now();
    _pausedAccum = Duration.zero;
    _pauseStart = null;
    paused = false;
    _settings.clearSave();
    HxAudio.instance.start();
    setState(() {});
    _maybeAi();
  }

  void _onPause({bool quiet = false}) {
    if (engine.over || paused) return;
    paused = true;
    _pauseStart = DateTime.now();
    _aiGen++; // cancel pending AI move; re-armed on resume
    _aiThinking = false;
    if (!quiet) HxAudio.instance.click();
    _saveGame();
    setState(() {});
  }

  void _onResume() {
    if (!paused) return;
    if (_pauseStart != null) {
      _pausedAccum += DateTime.now().difference(_pauseStart!);
      _pauseStart = null;
    }
    paused = false;
    HxAudio.instance.click();
    setState(() {});
    _maybeAi();
  }

  void _onResign() {
    HxAudio.instance.click();
    engine.resign(widget.vsAi ? _humanColor : engine.turn);
    paused = false;
    _pauseStart = null;
    _onGameOver();
  }

  void _onQuitToMenu() {
    HxAudio.instance.click();
    _aiGen++;
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
                  Expanded(child: _buildBoard()),
                  _buildThumbRail(),
                ],
              ),
              if (_awaitingSwap) _buildSwapPrompt(),
              if (paused && !engine.over) _buildPauseOverlay(),
              if (engine.over) _buildVictoryOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPlaque() {
    final turnName = HxSettings.playerNames[engine.turn];
    String status;
    if (engine.over) {
      status = '${HxSettings.playerNames[engine.winner ?? 0]} wins';
    } else if (_awaitingSwap) {
      status = 'Indigo may swap colors!';
    } else if (widget.vsAi && _aiThinking) {
      status = 'AI is thinking…';
    } else if (widget.vsAi) {
      status = engine.turn == _humanColor ? 'Your move' : 'AI\'s move';
    } else {
      status = '$turnName to move';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: HxTheme.clayPlaque(radius: 14),
        child: Row(
          children: [
            GlazedHexIcon(size: 40, player: engine.turn),
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

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return GestureDetector(
          onTapUp: (d) {
            final painter = _BoardPainter(engine: engine);
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
    final undoEnabled = !engine.over &&
        !engine.swapAvailable &&
        engine.history.isNotEmpty &&
        !_aiThinking;
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
                    children: const [
                      GlazedHexIcon(size: 44, player: 0),
                      SizedBox(width: 8),
                      Icon(Icons.swap_horiz,
                          size: 30, color: HxTheme.carved),
                      SizedBox(width: 8),
                      GlazedHexIcon(size: 44, player: 1),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Pie rule — swap?',
                      style: HxTheme.plaqueTitle, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Terracotta opened strong. As Indigo, you may swap colors and steal that tile — or play on.',
                    style: HxTheme.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ClayButton(
                      label: 'Swap tiles',
                      glazeColor: HxTheme.indigo,
                      onTap: () => _doSwap(byAi: false)),
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
                  child: Text('Paused',
                      style: HxTheme.title(30, HxTheme.cream)),
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
    final wName = HxSettings.playerNames[w];
    final title = engine.resigned
        ? '$wName wins — rival resigned'
        : '$wName wins!';
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
                  child: GlazedHexIcon(size: 110, player: w),
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
                    glazeColor: w == 0 ? HxTheme.terracotta : HxTheme.indigo,
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

// ==================== BOARD PAINTER ====================
/// Pseudo-3D ceramic board: walnut tray, mortised wells, extruded glazed
/// tiles with bevels, specular highlights and contact shadows.
class _BoardPainter extends CustomPainter {
  final HexEngine engine;
  final List<int>? placeCell;
  final double placeT; // 0..1 weighted-settle progress

  late int n;
  double _s = 18;
  Offset _origin = Offset.zero;

  _BoardPainter({required this.engine, this.placeCell, this.placeT = 1.0}) {
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

    final tray = [push(cT, _s * 2.0), push(cR, _s * 2.0),
        push(cB, _s * 2.0), push(cL, _s * 2.0)];
    final field = [push(cT, _s * 0.7), push(cR, _s * 0.7),
        push(cB, _s * 0.7), push(cL, _s * 0.7)];

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
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4E3A28), HxTheme.walnut, HxTheme.walnutDeep],
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
            ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.3),
              colors: [Color(0xFF5A422C), Color(0xFF2A1C10)],
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
            colors: const [Color(0xFF2E2013), Color(0xFF1C120A)],
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

    inlay(field[0], field[1], HxTheme.terracotta); // top
    inlay(field[3], field[2], HxTheme.terracotta); // bottom
    inlay(field[0], field[3], HxTheme.indigo); // left
    inlay(field[1], field[2], HxTheme.indigo); // right
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
          _paintTile(canvas, c + Offset(0, dy), _s * 0.94, v, scale,
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
            colors: const [Color(0xFF241708), Color(0xFF140D05)],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(
        path,
        Paint()
          ..color = HxTheme.kiln
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, _s * 0.07));
    // Light catching the lower-right inner wall (kiln light from upper-left).
    final corners = List.generate(
        6,
        (i) => Offset(c.dx + r * cos((60 * i - 30) * pi / 180),
            c.dy + r * sin((60 * i - 30) * pi / 180)));
    canvas.drawLine(
        corners[0],
        corners[1],
        Paint()
          ..color = HxTheme.cream.withValues(alpha: 0.10)
          ..strokeWidth = max(1, _s * 0.06)
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        corners[1],
        corners[2],
        Paint()
          ..color = HxTheme.cream.withValues(alpha: 0.10)
          ..strokeWidth = max(1, _s * 0.06)
          ..strokeCap = StrokeCap.round);
  }

  /// Chunky glazed hex tile: contact shadow, extruded body, pillowed glaze
  /// top with specular highlight and bevel.
  void _paintTile(Canvas canvas, Offset c, double r, int player, double scale,
      {bool inWin = false}) {
    final (hi, mid, lo) = HxTheme.glaze(player);
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

    // Glazed top face: pooling highlight upper-left.
    final top = hexPath(c, r * 0.97);
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
    // Specular pill (glaze pooling).
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(-r * 0.24, -r * 0.30),
            width: r * 0.52,
            height: r * 0.26),
        Paint()..color = Colors.white.withValues(alpha: 0.38));
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(r * 0.30, r * 0.34),
            width: r * 0.30,
            height: r * 0.14),
        Paint()..color = Colors.white.withValues(alpha: 0.10));

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
            ..color = HxTheme.kiln.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.5, _s * 0.16));
      canvas.save();
      canvas.translate(0, 1.5);
      canvas.drawPath(
          path,
          Paint()
            ..color = HxTheme.cream.withValues(alpha: 0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1, _s * 0.06));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
