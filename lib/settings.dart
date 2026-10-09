import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings + match tally for Hex (Atelier Hex).
class HxSettings {
  HxSettings._();
  static final HxSettings instance = HxSettings._();

  /// Board size: 7, 9, 11 (default) or 13.
  int boardSize = 11;

  /// AI difficulty: 0 = Gentle, 1 = Steady (default), 2 = Master.
  int difficulty = 1;

  /// Which color the human plays in vs-AI: 0 = Terracotta, 1 = Indigo.
  int humanColor = 0;

  /// Pie rule (swap) enabled by default.
  bool pieRule = true;

  int terracottaWins = 0;
  int indigoWins = 0;
  int gamesPlayed = 0;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    final p = await SharedPreferences.getInstance();
    boardSize = p.getInt('hx_board_size') ?? 11;
    if (!boardSizes.contains(boardSize)) boardSize = 11;
    difficulty = p.getInt('hx_difficulty') ?? 1;
    humanColor = p.getInt('hx_human_color') ?? 0;
    pieRule = p.getBool('hx_pie_rule') ?? true;
    terracottaWins = p.getInt('hx_terra_wins') ?? 0;
    indigoWins = p.getInt('hx_indigo_wins') ?? 0;
    gamesPlayed = p.getInt('hx_games') ?? 0;
    _ready = true;
  }

  Future<void> setBoardSize(int v) async {
    boardSize = v;
    (await SharedPreferences.getInstance()).setInt('hx_board_size', v);
  }

  Future<void> setDifficulty(int v) async {
    difficulty = v.clamp(0, 2);
    (await SharedPreferences.getInstance()).setInt('hx_difficulty', difficulty);
  }

  Future<void> setHumanColor(int v) async {
    humanColor = v.clamp(0, 1);
    (await SharedPreferences.getInstance()).setInt('hx_human_color', humanColor);
  }

  Future<void> setPieRule(bool v) async {
    pieRule = v;
    (await SharedPreferences.getInstance()).setBool('hx_pie_rule', v);
  }

  /// result: 0 = terracotta wins, 1 = indigo wins.
  Future<void> recordResult(int result) async {
    final p = await SharedPreferences.getInstance();
    gamesPlayed++;
    await p.setInt('hx_games', gamesPlayed);
    if (result == 0) {
      terracottaWins++;
      await p.setInt('hx_terra_wins', terracottaWins);
    } else {
      indigoWins++;
      await p.setInt('hx_indigo_wins', indigoWins);
    }
  }

  static const boardSizes = [7, 9, 11, 13];
  static const difficulties = ['Gentle', 'Steady', 'Master'];
  static const playerNames = ['Terracotta', 'Indigo'];

  // ---- Saved in-progress game (pause/kill-restore, RULES.md test 20) ----
  Future<bool> get hasSave async =>
      (await SharedPreferences.getInstance()).containsKey('hx_save');

  Future<void> saveGame(String json) async {
    (await SharedPreferences.getInstance()).setString('hx_save', json);
  }

  Future<String?> loadGame() async =>
      (await SharedPreferences.getInstance()).getString('hx_save');

  Future<void> clearSave() async {
    (await SharedPreferences.getInstance()).remove('hx_save');
  }
}
