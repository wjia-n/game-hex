import 'package:shared_preferences/shared_preferences.dart';

import 'hex_themes.dart';

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

  /// Renameable player display names (both slots), persisted.
  List<String> playerNames = ['Terracotta', 'Indigo'];

  /// Theme id from [HxThemes], 'custom' for the user creation.
  String themeId = 'classic';

  /// Tile glaze style index (see [HxTileStyles]).
  int tileStyle = 0;

  /// Custom theme colors (ARGB ints); edited in the creator screen.
  Map<String, int> customColors = {};

  /// Pro unlock (from the real purchase; also flippable by the store).
  bool isPro = false;

  /// Audio toggles + volume (applied to HxAudio at launch).
  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  int terracottaWins = 0;
  int indigoWins = 0;
  int gamesPlayed = 0;

  bool _ready = false;

  String nameOf(int player) =>
      playerNames[player.clamp(0, 1)].trim().isEmpty
          ? (player == 0 ? 'Terracotta' : 'Indigo')
          : playerNames[player.clamp(0, 1)].trim();

  Future<void> init() async {
    if (_ready) return;
    final p = await SharedPreferences.getInstance();
    boardSize = p.getInt('hx_board_size') ?? 11;
    if (!boardSizes.contains(boardSize)) boardSize = 11;
    difficulty = (p.getInt('hx_difficulty') ?? 1).clamp(0, 2);
    humanColor = (p.getInt('hx_human_color') ?? 0).clamp(0, 1);
    pieRule = p.getBool('hx_pie_rule') ?? true;
    final names = p.getStringList('hx_names');
    if (names != null && names.length == 2) {
      playerNames = [
        names[0].trim().isEmpty ? 'Terracotta' : names[0].trim(),
        names[1].trim().isEmpty ? 'Indigo' : names[1].trim(),
      ];
    }
    themeId = p.getString('hx_theme_id') ?? 'classic';
    tileStyle =
        (p.getInt('hx_tile_style') ?? 0).clamp(0, HxTileStyles.names.length - 1);
    isPro = p.getBool('hx_is_pro') ?? false;
    musicOn = p.getBool('hx_music_on') ?? true;
    sfxOn = p.getBool('hx_sfx_on') ?? true;
    volume = (p.getDouble('hx_volume') ?? 0.8).clamp(0.0, 1.0);
    for (final k in HxThemes.all[0].toCustomColors().keys) {
      customColors[k] = p.getInt('hx_custom_$k') ??
          HxThemes.all[0].toCustomColors()[k]!;
    }
    terracottaWins = p.getInt('hx_terra_wins') ?? 0;
    indigoWins = p.getInt('hx_indigo_wins') ?? 0;
    gamesPlayed = p.getInt('hx_games') ?? 0;
    _ready = true;
    _enforceFreeLimits();
  }

  /// Free tier keeps only the free themes/styles; silently downgrade.
  void _enforceFreeLimits() {
    if (!isPro) {
      if (!HxThemes.isFree(themeId) && themeId != 'custom') {
        themeId = 'classic';
      }
      if (themeId == 'custom') themeId = 'classic';
      if (!HxTileStyles.isFree(tileStyle)) tileStyle = 0;
    }
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

  Future<void> setPlayerName(int player, String name) async {
    playerNames[player.clamp(0, 1)] = name.trim().isEmpty
        ? (player == 0 ? 'Terracotta' : 'Indigo')
        : name.trim();
    (await SharedPreferences.getInstance())
        .setStringList('hx_names', playerNames);
  }

  Future<void> setTheme(String id) async {
    if (!isPro && !HxThemes.isFree(id)) return; // Pro themes stay locked
    themeId = id;
    (await SharedPreferences.getInstance()).setString('hx_theme_id', id);
  }

  Future<void> setTileStyle(int i) async {
    i = i.clamp(0, HxTileStyles.names.length - 1);
    if (!isPro && !HxTileStyles.isFree(i)) return; // Pro styles stay locked
    tileStyle = i;
    (await SharedPreferences.getInstance()).setInt('hx_tile_style', i);
  }

  Future<void> setCustomColor(String key, int argb) async {
    customColors[key] = argb;
    (await SharedPreferences.getInstance()).setInt('hx_custom_$key', argb);
  }

  Future<void> setPro(bool v) async {    isPro = v;
    (await SharedPreferences.getInstance()).setBool('hx_is_pro', v);
    _enforceFreeLimits();
    if (!isPro) {
      final p = await SharedPreferences.getInstance();
      await p.setString('hx_theme_id', themeId);
      await p.setInt('hx_tile_style', tileStyle);
    }
  }

  HxThemeDef get theme =>
      HxThemes.byId(themeId, custom: customColors);

  Future<void> setMusicOn(bool v) async {
    musicOn = v;
    (await SharedPreferences.getInstance()).setBool('hx_music_on', v);
  }

  Future<void> setSfxOn(bool v) async {
    sfxOn = v;
    (await SharedPreferences.getInstance()).setBool('hx_sfx_on', v);
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    (await SharedPreferences.getInstance()).setDouble('hx_volume', volume);
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
