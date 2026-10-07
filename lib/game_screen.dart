import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Hex — claim cells and connect your two sides. No draws, ever.
class HexScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const HexScreen({super.key, required this.players, required this.callbacks});

  @override
  State<HexScreen> createState() => _HexScreenState();
}

class _HexScreenState extends State<HexScreen> {
  static const n = 9;
  static const _dirs = [
    [1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]
  ];

  late List<List<int>> board; // -1 empty, else player index
  int turn = 0;
  bool over = false;
  List<List<int>>? winPath;
  final _rnd = Random();
  late _HexBoardPainter _painter;

  @override
  void initState() {
    super.initState();
    _reset();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBot());
  }

  void _reset() {
    board = List.generate(n, (_) => List.filled(n, -1));
    turn = 0;
    over = false;
    winPath = null;
    _refreshPainter();
    widget.callbacks.setActivePlayer(0);
  }

  void _refreshPainter() {
    final t = ThemeController.of(context).theme;
    _painter = _HexBoardPainter(
      board: board,
      players: widget.players,
      winPath: winPath,
      surface: t.surface,
      line: t.primary.withValues(alpha: 0.35),
    );
  }

  void _tapCell(int q, int r) {
    if (over || board[q][r] != -1 || widget.players[turn].isBot) return;
    _claim(q, r);
  }

  void _claim(int q, int r) {
    setState(() {
      board[q][r] = turn;
      _refreshPainter();
    });
    Sfx.tap();
    final path = _winPath(turn);
    if (path != null) {
      _endGame(path);
      return;
    }
    setState(() => turn = 1 - turn);
    widget.callbacks.setActivePlayer(turn);
    _maybeBot();
  }

  /// BFS for a connecting path; returns the path or null.
  List<List<int>>? _winPath(int p) {
    final prev = <String, String>{};
    final queue = <List<int>>[];
    final seen = <String>{};
    String key(int q, int r) => '$q,$r';
    bool isStart(int q, int r) => p == 0 ? r == 0 : q == 0;
    bool isGoal(int q, int r) => p == 0 ? r == n - 1 : q == n - 1;

    for (int q = 0; q < n; q++) {
      for (int r = 0; r < n; r++) {
        if (board[q][r] == p && isStart(q, r)) {
          queue.add([q, r]);
          seen.add(key(q, r));
        }
      }
    }
    while (queue.isNotEmpty) {
      final cell = queue.removeAt(0);
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
      for (final d in _dirs) {
        final nq = q + d[0], nr = r + d[1];
        if (nq < 0 || nr < 0 || nq >= n || nr >= n) continue;
        if (board[nq][nr] != p || seen.contains(key(nq, nr))) continue;
        seen.add(key(nq, nr));
        prev[key(nq, nr)] = key(q, r);
        queue.add([nq, nr]);
      }
    }
    return null;
  }

  void _maybeBot() {
    if (over || !widget.players[turn].isBot) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || over || !widget.players[turn].isBot) return;
      final c = _botChoice();
      _claim(c[0], c[1]);
    });
  }

  List<int> _botChoice() {
    final me = turn, foe = 1 - turn;
    final empties = <List<int>>[
      for (int q = 0; q < n; q++)
        for (int r = 0; r < n; r++)
          if (board[q][r] == -1) [q, r]
    ];
    // 1. win now
    for (final e in empties) {
      board[e[0]][e[1]] = me;
      final w = _winPath(me) != null;
      board[e[0]][e[1]] = -1;
      if (w) return e;
    }
    // 2. block foe's immediate win
    for (final e in empties) {
      board[e[0]][e[1]] = foe;
      final w = _winPath(foe) != null;
      board[e[0]][e[1]] = -1;
      if (w) return e;
    }
    // 3. heuristic: hug own stones, love bridges, drift center
    var best = empties.first;
    var bestScore = -1e9;
    for (final e in empties) {
      final q = e[0], r = e[1];
      var own = 0, empty = 0;
      for (final d in _dirs) {
        final nq = q + d[0], nr = r + d[1];
        if (nq < 0 || nr < 0 || nq >= n || nr >= n) continue;
        if (board[nq][nr] == me) {
          own++;
        } else if (board[nq][nr] == -1) {
          empty++;
        }
      }
      final centerBias = 8 - ((q - 4).abs() + (r - 4).abs());
      final score = own * 4 + empty * 0.6 + centerBias * 0.4 + _rnd.nextDouble() * 3;
      if (score > bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best;
  }

  void _endGame(List<List<int>> path) {
    setState(() {
      over = true;
      winPath = path;
      _refreshPainter();
    });
    final w = widget.players[turn];
    w.score += 1;
    widget.callbacks.refreshHud();
    Sfx.win();
    widget.callbacks.finish(
      winner: w,
      headline: '${w.name} bridged it! ⬡🎉',
      subline: turn == 0 ? 'Top to bottom — a flawless connection!' : 'Side to side — a flawless connection!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final current = widget.players[turn];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!over)
            TurnBanner(
              player: current,
              action: current.isBot
                  ? ' is plotting… 🤖'
                  : (turn == 0 ? ' — connect TOP ⬆ to BOTTOM ⬇' : ' — connect LEFT ⬅ to RIGHT ➡'),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: t.radius,
                    boxShadow: [
                      BoxShadow(
                          color: t.primary.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Builder(
                    builder: (ctx) => GestureDetector(
                      onTapUp: (d) {
                        final box = ctx.findRenderObject() as RenderBox;
                        final cell = _painter.cellAt(d.localPosition, box.size);
                        if (cell != null) _tapCell(cell[0], cell[1]);
                      },
                      child: CustomPaint(painter: _painter),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Every game has a winner. No draws. No mercy. 😎',
              style: TextStyle(color: t.muted, fontSize: 13)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _HexBoardPainter extends CustomPainter {
  final List<List<int>> board;
  final List<Player> players;
  final List<List<int>>? winPath;
  final Color surface;
  final Color line;

  double _s = 20;
  Offset _origin = Offset.zero;

  _HexBoardPainter({
    required this.board,
    required this.players,
    required this.winPath,
    required this.surface,
    required this.line,
  });

  static const n = 9;

  Offset _centerOf(int q, int r) => Offset(
        _origin.dx + _s * sqrt(3) * (q + r / 2),
        _origin.dy + _s * 1.5 * r,
      );

  Offset _corner(Offset c, int i) {
    final a = pi / 180 * (60 * i - 30);
    return Offset(c.dx + _s * cos(a), c.dy + _s * sin(a));
  }

  void _measure(Size size) {
    const pad = 16.0;
    _s = (size.width - pad * 2) / (sqrt(3) * 13);
    final totalW = sqrt(3) * _s * 13;
    final totalH = 1.5 * _s * 8 + 2 * _s;
    _origin = Offset(
      (size.width - totalW) / 2 + sqrt(3) / 2 * _s,
      (size.height - totalH) / 2 + _s,
    );
  }

  /// Hit-test a tap in paint coordinates.
  List<int>? cellAt(Offset p, Size size) {
    _measure(size);
    var bestD = 1e9;
    List<int>? best;
    for (int q = 0; q < n; q++) {
      for (int r = 0; r < n; r++) {
        final d = (p - _centerOf(q, r)).distance;
        if (d < bestD) {
          bestD = d;
          best = [q, r];
        }
      }
    }
    return bestD <= _s ? best : null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _measure(size);
    final winSet =
        winPath == null ? <String>{} : winPath!.map((c) => '${c[0]},${c[1]}').toSet();

    // Edge glow frame: top/bottom edges = player 0, left/right = player 1.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    edge.color = players[0].color.withValues(alpha: 0.85);
    canvas.drawLine(_corner(_centerOf(0, 0), 4), _corner(_centerOf(8, 0), 0), edge);
    canvas.drawLine(_corner(_centerOf(0, 8), 3), _corner(_centerOf(8, 8), 1), edge);
    edge.color = players[1].color.withValues(alpha: 0.85);
    canvas.drawLine(_corner(_centerOf(0, 0), 4), _corner(_centerOf(0, 8), 3), edge);
    canvas.drawLine(_corner(_centerOf(8, 0), 0), _corner(_centerOf(8, 8), 1), edge);

    for (int q = 0; q < n; q++) {
      for (int r = 0; r < n; r++) {
        final c = _centerOf(q, r);
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final p = _corner(c, i);
          // shrink slightly for gaps
          final sp = c + (p - c) * 0.94;
          if (i == 0) {
            path.moveTo(sp.dx, sp.dy);
          } else {
            path.lineTo(sp.dx, sp.dy);
          }
        }
        path.close();
        final v = board[q][r];
        final inWin = winSet.contains('$q,$r');
        canvas.drawPath(
          path,
          Paint()
            ..color = v == -1
                ? surface
                : players[v].color.withValues(alpha: inWin ? 1.0 : 0.82),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = inWin ? 3.2 : 1.4
            ..color = inWin && v != -1 ? players[v].color : line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexBoardPainter old) => true;
}
