import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Hex game engine — deterministic rules per RULES.md.
/// Terracotta (player 0) connects TOP <-> BOTTOM edges.
/// Indigo (player 1) connects LEFT <-> RIGHT edges.
///
/// The engine owns ALL turn state (the UI never runs its own turn timers):
/// - [phase] is the single source of truth for whose turn it is and what the
///   game is waiting for.
/// - Bot turns are scheduled by the engine on its single phase timer [_timer]
///   (the "thinking" beat that makes bot turns visible).
/// - A 3-second [_watchdog] calls [recover], which re-arms any phase found
///   without a live timer — stuck states are impossible by construction.
/// Win detection is a flood fill (BFS) from each player's start edge; draws
/// are impossible in Hex (a full rhombus always holds exactly one winner).
enum HexPhase {
  /// Waiting for the current (human) player to place a tile.
  awaitingMove,

  /// Indigo (human) must choose swap-or-play; no other action is legal.
  awaitingSwap,

  /// Bot's turn: the engine will place its tile when the think timer fires.
  aiThinking,

  /// A move just landed; brief beat so the placement animates visibly.
  settling,

  /// Game over (win or resignation).
  done,
}

class HexEngine extends ChangeNotifier {
  static const dirs = [
    [1, 0],
    [1, -1],
    [0, -1],
    [-1, 0],
    [-1, 1],
    [0, 1],
  ];

  int size;
  late List<List<int>> board; // -1 empty, 0 terracotta, 1 indigo
  int turn = 0; // 0 terracotta, 1 indigo
  bool over = false;
  int? winner; // 0/1 when over
  bool resigned = false;
  bool pieRuleEnabled;
  bool swapAvailable = false; // indigo may swap instead of playing
  bool swapUsed = false;
  List<List<int>>? winPath;

  /// Move history for undo: [q, r] of each placement, in order.
  final List<List<int>> history = [];

  /// History length at the moment the swap window resolved (undo floor).
  int _undoFloor = 0;

  // ---------------- turn director ----------------
  HexPhase phase = HexPhase.awaitingMove;
  bool paused = false;

  /// Which color indexes are bots: index 0 = terracotta, 1 = indigo.
  List<bool> isBot = [false, false];
  int botDifficulty = 1; // 0 gentle, 1 steady, 2 master
  Duration thinkDelay = const Duration(milliseconds: 850);

  /// The most recent placement, for the UI's placement animation.
  List<int>? lastMove;

  final HexAI ai = HexAI();
  final Random _jitter = Random();

  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;

  HexEngine({required this.size, this.pieRuleEnabled = true}) {
    reset();
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => recover());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  /// Configure bot sides before [begin]. [bots] has one entry per color.
  void configure(
      {required List<bool> bots, required int difficulty, Duration? thinkDelay}) {
    isBot = [bots[0], bots[1]];
    botDifficulty = difficulty.clamp(0, 2);
    if (thinkDelay != null) this.thinkDelay = thinkDelay;
  }

  /// Start (or restart) the turn director after setup / restore / resume.
  void begin() {
    if (_disposed || over) {
      if (over) phase = HexPhase.done;
      return;
    }
    _afterPhase();
  }

  void reset() {
    board = List.generate(size, (_) => List.filled(size, -1));
    turn = 0;
    over = false;
    winner = null;
    resigned = false;
    swapAvailable = false;
    swapUsed = false;
    winPath = null;
    lastMove = null;
    history.clear();
    _undoFloor = 0;
    phase = HexPhase.awaitingMove;
    _timer?.cancel();
    _timer = null;
  }

  // ---------------- director internals ----------------

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Re-evaluate the current phase and schedule whatever comes next.
  void _afterPhase() {
    if (_disposed || paused) return;
    if (over) {
      phase = HexPhase.done;
      notifyListeners();
      return;
    }
    if (canSwap) {
      if (isBot[turn]) {
        phase = HexPhase.aiThinking;
        notifyListeners();
        _arm(thinkDelay, _doAiTurn);
      } else {
        phase = HexPhase.awaitingSwap;
        notifyListeners();
      }
      return;
    }
    if (isBot[turn]) {
      phase = HexPhase.aiThinking;
      notifyListeners();
      final jitterMs = _jitter.nextInt(400);
      _arm(thinkDelay + Duration(milliseconds: jitterMs), _doAiTurn);
    } else {
      phase = HexPhase.awaitingMove;
      notifyListeners();
    }
  }

  /// The bot's scheduled turn: swap decision or placement.
  void _doAiTurn() {
    if (_disposed || paused || over) return;
    if (!isBot[turn]) return; // human took over meanwhile; stay put
    if (canSwap) {
      if (ai.shouldSwap(this, history.first)) {
        swap();
      } else {
        declineSwap();
      }
      _settle();
      return;
    }
    final mv = ai.chooseMove(this, turn, botDifficulty);
    if (mv[0] < 0 || !play(mv[0], mv[1])) {
      // Should never happen (a legal move always exists); the watchdog
      // re-arms rather than letting the game stall.
      _afterPhase();
      return;
    }
    lastMove = mv;
    _settle();
  }

  /// Brief beat after any move so the placement animation reads, then on.
  void _settle() {
    if (_disposed) return;
    phase = HexPhase.settling;
    notifyListeners();
    _arm(const Duration(milliseconds: 320), _afterPhase);
  }

  /// Pause: freeze the phase timer. Resume re-arms the current phase via
  /// the watchdog path.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
    } else {
      recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// Stuck states are impossible by construction. Respects [paused].
  /// Public so tests (and the periodic timer) can tick it directly.
  void recover() {
    if (_disposed || over || paused || _timer != null) return;
    if (phase == HexPhase.aiThinking && isBot[turn]) {
      _doAiTurn(); // bot turn with no timer: act immediately
    } else if (phase == HexPhase.settling) {
      _afterPhase(); // interrupted settle: move on
    } else if (phase == HexPhase.awaitingMove && isBot[turn]) {
      _afterPhase(); // missed arm: schedule the bot turn
    } else if (phase == HexPhase.awaitingSwap && isBot[turn] && canSwap) {
      _doAiTurn(); // bot holding the swap option with no timer
    }
    // awaitingMove/awaitingSwap for a human, and done: correctly idle.
  }

  /// Test hook: drop the live phase timer without making progress, so the
  /// watchdog recovery path can be exercised deterministically.
  @visibleForTesting
  void debugDropTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ---------------- human actions (UI calls these) ----------------

  bool get _humanMayAct =>
      !_disposed &&
      !paused &&
      !over &&
      !isBot[turn] &&
      phase == HexPhase.awaitingMove;

  /// Human places a tile. Returns false when illegal (wrong phase, bot's
  /// turn, occupied cell, off board).
  bool humanPlay(int q, int r) {
    if (!_humanMayAct) return false;
    if (!play(q, r)) return false;
    lastMove = [q, r];
    _settle();
    return true;
  }

  /// Human (Indigo) takes the swap. Returns false outside the swap window.
  bool humanSwap() {
    if (_disposed || paused || over || isBot[turn]) return false;
    if (!swap()) return false;
    _settle();
    return true;
  }

  /// Human (Indigo) declines the swap and will play a normal move.
  void humanDeclineSwap() {
    if (_disposed || paused || over || isBot[turn]) return;
    declineSwap();
    _afterPhase();
  }

  /// Undo [plies] half-moves; cancels any pending bot turn. Returns the
  /// number of plies actually removed.
  int humanUndo(int plies) {
    if (_disposed || paused || over || swapAvailable) return 0;
    if (phase == HexPhase.aiThinking) return 0; // let the bot finish visibly
    _timer?.cancel();
    _timer = null;
    final removed = undo(plies);
    if (removed > 0) {
      lastMove = null;
      _afterPhase();
    }
    return removed;
  }

  /// A player resigns; the opponent wins immediately.
  void humanResign(int player) {
    if (_disposed || over) return;
    _timer?.cancel();
    _timer = null;
    resign(player);
    phase = HexPhase.done;
    notifyListeners();
  }

  // ---------------- core rules (unchanged semantics) ----------------

  bool get canSwap =>
      !over && pieRuleEnabled && swapAvailable && history.length == 1;

  bool inBounds(int q, int r) => q >= 0 && r >= 0 && q < size && r < size;

  /// Attempts to place the current player's tile. Returns false if illegal.
  bool play(int q, int r) {
    if (over || !inBounds(q, r) || board[q][r] != -1) return false;
    board[q][r] = turn;
    history.add([q, r]);
    final path = winPathFor(turn);
    if (path != null) {
      over = true;
      winner = turn;
      winPath = path;
      swapAvailable = false;
      phase = HexPhase.done;
      notifyListeners();
      return true;
    }
    // Resolve the swap window: after indigo's first turn it expires.
    if (swapAvailable && turn == 1) {
      swapAvailable = false;
      _undoFloor = history.length; // cannot undo across the swap window
    } else if (history.length == 1 && turn == 0 && pieRuleEnabled) {
      swapAvailable = true;
    }
    turn = 1 - turn;
    return true;
  }

  /// Indigo declines the swap: the window expires permanently.
  void declineSwap() {
    if (!canSwap) return;
    swapAvailable = false;
    _undoFloor = history.length;
    turn = 1; // indigo (the decliner) now plays their first turn
  }

  /// Pie rule: the two players swap colors; the opening tile keeps its
  /// color (it now belongs to the new Terracotta). Uses up Indigo's
  /// first turn. Returns false if not currently allowed.
  bool swap() {
    if (!canSwap) return false;
    swapUsed = true;
    swapAvailable = false;
    _undoFloor = history.length; // cannot undo across the swap
    // The players trade colors, so bot-ness follows the seat, not the
    // color index — otherwise the director would drive the wrong side
    // for the rest of the game.
    final b = isBot[0];
    isBot[0] = isBot[1];
    isBot[1] = b;
    turn = 1; // the (new) indigo moves next
    return true;
  }

  /// Undo [plies] half-moves, never crossing the swap-resolution floor.
  /// Returns the number of plies actually removed.
  int undo(int plies) {
    if (over || swapAvailable) return 0;
    var removed = 0;
    while (removed < plies && history.length > _undoFloor) {
      final m = history.removeLast();
      board[m[0]][m[1]] = -1;
      removed++;
      turn = 1 - turn;
    }
    winPath = null;
    return removed;
  }

  /// A player resigns; the opponent wins immediately.
  void resign(int player) {
    if (over) return;
    over = true;
    resigned = true;
    winner = 1 - player;
    winPath = null;
    swapAvailable = false;
  }

  int get moveCount => history.length;

  int placedCount(int p) {
    var c = 0;
    for (int q = 0; q < size; q++) {
      for (int r = 0; r < size; r++) {
        if (board[q][r] == p) c++;
      }
    }
    return c;
  }

  /// Flood-fill win detection: returns the winning chain (list of [q,r])
  /// from the goal edge back to the start edge, or null.
  List<List<int>>? winPathFor(int p) {
    final prev = <String, String>{};
    final queue = <List<int>>[];
    var head = 0;
    final seen = <String>{};
    String key(int q, int r) => '$q,$r';
    bool isStart(int q, int r) => p == 0 ? r == 0 : q == 0;
    bool isGoal(int q, int r) => p == 0 ? r == size - 1 : q == size - 1;

    for (int q = 0; q < size; q++) {
      for (int r = 0; r < size; r++) {
        if (board[q][r] == p && isStart(q, r)) {
          queue.add([q, r]);
          seen.add(key(q, r));
        }
      }
    }
    while (head < queue.length) {
      final cell = queue[head++];
      final q = cell[0], r = cell[1];
      if (isGoal(q, r)) {
        final path = <List<int>>[[q, r]];
        var k = key(q, r);
        while (prev.containsKey(k)) {
          k = prev[k]!;
          final parts = k.split(',');
          path.add([int.parse(parts[0]), int.parse(parts[1])]);
        }
        return path;
      }
      for (final d in dirs) {
        final nq = q + d[0], nr = r + d[1];
        if (!inBounds(nq, nr)) continue;
        if (board[nq][nr] != p || seen.contains(key(nq, nr))) continue;
        seen.add(key(nq, nr));
        prev[key(nq, nr)] = key(q, r);
        queue.add([nq, nr]);
      }
    }
    return null;
  }

  List<List<int>> emptyCells() => [
        for (int q = 0; q < size; q++)
          for (int r = 0; r < size; r++)
            if (board[q][r] == -1) [q, r],
      ];

  /// Serialize for pause/kill-restore (RULES.md test 20).
  Map<String, dynamic> toJson() => {
        'size': size,
        'board': board.map((row) => row.toList()).toList(),
        'turn': turn,
        'over': over,
        'winner': winner,
        'resigned': resigned,
        'pieRuleEnabled': pieRuleEnabled,
        'swapAvailable': swapAvailable,
        'swapUsed': swapUsed,
        'history': history.map((m) => m.toList()).toList(),
        'undoFloor': _undoFloor,
        'isBot': isBot,
        'botDifficulty': botDifficulty,
        'phase': phase.index,
      };

  static HexEngine fromJson(Map<String, dynamic> j) {
    final e = HexEngine(
      size: (j['size'] as num).toInt(),
      pieRuleEnabled: j['pieRuleEnabled'] as bool,
    );
    e.board = (j['board'] as List)
        .map((row) => (row as List).map((v) => (v as num).toInt()).toList())
        .toList();
    e.turn = (j['turn'] as num).toInt();
    e.over = j['over'] as bool;
    e.winner = j['winner'] as int?;
    e.resigned = j['resigned'] as bool;
    e.swapAvailable = j['swapAvailable'] as bool;
    e.swapUsed = j['swapUsed'] as bool;
    e.history
      ..clear()
      ..addAll((j['history'] as List).map(
          (m) => (m as List).map((v) => (v as num).toInt()).toList()));
    e._undoFloor = (j['undoFloor'] as num).toInt();
    final bots = j['isBot'] as List?;
    if (bots != null && bots.length == 2) {
      e.isBot = [bots[0] as bool, bots[1] as bool];
    }
    e.botDifficulty = (j['botDifficulty'] as num?)?.toInt() ?? 1;
    if (e.over && e.winner != null && !e.resigned) {
      e.winPath = e.winPathFor(e.winner!);
      e.phase = HexPhase.done;
    } else if (e.canSwap) {
      e.phase = HexPhase.awaitingSwap;
    } else {
      e.phase = HexPhase.awaitingMove;
    }
    return e;
  }
}

// ==================== AI ====================
/// Competent, explainable Hex AI per RULES.md section 11.
/// Difficulties: 0 = Gentle, 1 = Steady, 2 = Master.
class HexAI {
  final Random _rnd = Random();

  /// Choose [q, r] for [me] on [engine]. Honors [timeBudgetMs] for Master.
  List<int> chooseMove(HexEngine engine, int me, int difficulty,
      {int timeBudgetMs = 2000}) {
    final empties = engine.emptyCells();
    if (empties.isEmpty) return [-1, -1];
    final foe = 1 - me;

    // Opening: strong-but-not-maximal center-ish stone (RULES 11).
    if (engine.history.isEmpty) {
      final c = engine.size ~/ 2;
      final jx = _rnd.nextInt(3) - 1, jy = _rnd.nextInt(3) - 1;
      return [c + jx, c + jy];
    }

    // Gentle sometimes blunders on purpose (tactical errors, RULES 11);
    // Steady/Master always take the immediate win or block.
    final tactical = difficulty == 0 ? _rnd.nextDouble() < 0.35 : true;
    if (tactical) {
      // 1. Win immediately.
      final win = _findTactical(engine, me);
      if (win != null) return win;
      // 2. Block opponent's immediate win.
      final block = _findBlock(engine, foe);
      if (block != null) return block;
    }

    switch (difficulty) {
      case 0:
        return _gentle(engine, me, empties);
      case 2:
        return _master(engine, me, foe, empties, timeBudgetMs);
      case 1:
      default:
        return _steady(engine, me, empties);
    }
  }

  /// Should the AI (playing second) take the swap after [openingMove]?
  /// Swaps when the opening stone is strong for the first player.
  bool shouldSwap(HexEngine engine, List<int> openingMove) {
    final c = engine.size / 2;
    final dq = (openingMove[0] - c).abs();
    final dr = (openingMove[1] - c).abs();
    // Central-ish opening = strong first-player stone -> take it.
    return (dq + dr) <= engine.size / 3.2;
  }

  List<int>? _findTactical(HexEngine engine, int p) {
    for (final e in engine.emptyCells()) {
      engine.board[e[0]][e[1]] = p;
      final w = engine.winPathFor(p) != null;
      engine.board[e[0]][e[1]] = -1;
      if (w) return e;
    }
    return null;
  }

  /// Defensive 1-ply: all cells where [foe] would win immediately. If one,
  /// block it. If several, prefer a block that kills every threat (when
  /// such a block exists); otherwise block the first threat.
  List<int>? _findBlock(HexEngine engine, int foe) {
    final me = 1 - foe;
    final threats = <List<int>>[];
    for (final e in engine.emptyCells()) {
      engine.board[e[0]][e[1]] = foe;
      if (engine.winPathFor(foe) != null) threats.add(e);
      engine.board[e[0]][e[1]] = -1;
    }
    if (threats.isEmpty) return null;
    if (threats.length == 1) return threats.first;
    for (final b in engine.emptyCells()) {
      engine.board[b[0]][b[1]] = me;
      var ok = true;
      for (final t in threats) {
        if (engine.board[t[0]][t[1]] != -1) continue;
        engine.board[t[0]][t[1]] = foe;
        if (engine.winPathFor(foe) != null) ok = false;
        engine.board[t[0]][t[1]] = -1;
        if (!ok) break;
      }
      engine.board[b[0]][b[1]] = -1;
      if (ok) return b;
    }
    return threats.first;
  }

  /// Gentle: random legal move biased to cells adjacent to existing tiles;
  /// makes tactical errors (immediate wins/blocks often missed, see above).
  List<int> _gentle(HexEngine engine, int me, List<List<int>> empties) {
    // 25% of the time play pure random (extra blunder flavor).
    if (_rnd.nextDouble() < 0.25) {
      return empties[_rnd.nextInt(empties.length)];
    }
    return _bestByStatic(engine, me, empties, jitter: 6.0);
  }

  /// Steady: 1-ply tactical search (win/block above) + bridge heuristics
  /// + influence + mild randomness.
  List<int> _steady(HexEngine engine, int me, List<List<int>> empties) {
    return _bestByStatic(engine, me, empties, jitter: 1.5);
  }

  List<int> _bestByStatic(
      HexEngine engine, int me, List<List<int>> empties, {double jitter = 0}) {
    var best = empties.first;
    var bestScore = -1e18;
    for (final e in empties) {
      final s = _staticScore(engine, e[0], e[1], me) + _rnd.nextDouble() * jitter;
      if (s > bestScore) {
        bestScore = s;
        best = e;
      }
    }
    return best;
  }

  /// Master: 2-ply minimax over heuristically-pruned candidates with a
  /// strict time budget; falls back to the best move found so far.
  List<int> _master(HexEngine engine, int me, int foe,
      List<List<int>> empties, int timeBudgetMs) {
    final stopwatch = Stopwatch()..start();
    // Candidate pruning: score all empties statically, keep the top K.
    final scored = empties
        .map((e) => MapEntry(e, _staticScore(engine, e[0], e[1], me)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final k = min(20, scored.length);
    final candidates = scored.take(k).map((e) => e.key).toList();

    var best = candidates.first;
    var bestScore = -1e18;
    for (final c in candidates) {
      if (stopwatch.elapsedMilliseconds > timeBudgetMs) break;
      engine.board[c[0]][c[1]] = me;
      // Opponent's best reply (static).
      var reply = -1e18;
      for (final e in engine.emptyCells()) {
        reply = max(reply, _staticScore(engine, e[0], e[1], foe));
      }
      engine.board[c[0]][c[1]] = -1;
      final s = _staticScore(engine, c[0], c[1], me) - reply * 0.85;
      if (s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    return best;
  }

  /// Static cell score: bridges, adjacency influence, edge progress, center.
  double _staticScore(HexEngine engine, int q, int r, int me) {
    final foe = 1 - me;
    final n = engine.size;
    var score = 0.0;
    var own = 0;
    for (final d in HexEngine.dirs) {
      final nq = q + d[0], nr = r + d[1];
      if (!engine.inBounds(nq, nr)) continue;
      final v = engine.board[nq][nr];
      if (v == me) {
        own++;
        score += 4.0;
      } else if (v == foe) {
        score += 1.2; // contesting enemy influence
      } else {
        score += 0.5;
      }
    }
    // Bridge pattern: friendly stones two apart with this cell completing
    // the virtual connection (the two gap cells of a bridge).
    for (final b in _bridgeCells(engine, q, r)) {
      if (engine.board[b[0]][b[1]] == me) score += 3.0;
      if (engine.board[b[0]][b[1]] == foe) score -= 2.0;
    }
    // Edge progress: cells on the player's own target edges.
    final onOwnEdge = me == 0 ? (r == 0 || r == n - 1) : (q == 0 || q == n - 1);
    if (onOwnEdge) score += 2.0;
    // Center drift + mild influence for connected groups.
    final c = (n - 1) / 2;
    score += (n - ((q - c).abs() + (r - c).abs())) * 0.25;
    score += own * 0.8;
    return score;
  }

  /// The 6 bridge cells through (q, r): friendly stones on these cells form
  /// a virtual connection (bridge) with a stone at (q, r).
  Iterable<List<int>> _bridgeCells(HexEngine engine, int q, int r) sync* {
    // d1+d2 for adjacent (60-degree) neighbor-direction pairs.
    const steps = [
      [2, -1],
      [1, 1],
      [1, -2],
      [-1, -1],
      [-2, 1],
      [-1, 2],
    ];
    for (final s in steps) {
      final nq = q + s[0], nr = r + s[1];
      if (engine.inBounds(nq, nr)) yield [nq, nr];
    }
  }
}
