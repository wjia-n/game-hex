import 'dart:convert';

import 'package:flutter/material.dart';
import 'audio.dart';
import 'custom_theme_screen.dart';
import 'hex_theme.dart';
import 'hex_themes.dart';
import 'game_screen.dart';
import 'iap_service.dart';
import 'pro_screen.dart';
import 'settings.dart';
import 'splash_screen.dart';

/// Shared store for the whole app (initialized once at launch).
final StoreService hexStore = StoreService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HxAudio.instance.init();
  await HxSettings.instance.init();
  HxAudio.instance.configure(
    musicOn: HxSettings.instance.musicOn,
    sfxOn: HxSettings.instance.sfxOn,
    volume: HxSettings.instance.volume,
  );
  await hexStore.init();
  runApp(const HexApp());
}

class HexApp extends StatefulWidget {
  const HexApp({super.key});

  @override
  State<HexApp> createState() => _HexAppState();
}

class _HexAppState extends State<HexApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App-scoped music: pause (not stop) on backgrounding, resume on return.
    if (state == AppLifecycleState.paused) {
      HxAudio.instance.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      HxAudio.instance.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: HxTheme.oak,
        fontFamily: HxTheme.bodyFamily,
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== MAIN MENU ====================

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    HxAudio.instance.startMenuMusic();
    _checkSave();
  }

  Future<void> _checkSave() async {
    _hasSave = await HxSettings.instance.hasSave;
    if (mounted) setState(() {});
  }

  void _play(bool vsAi) {
    HxAudio.instance.click();
    HxAudio.instance.startGameMusic();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => HexGameScreen(vsAi: vsAi)))
        .then((_) {
      HxAudio.instance.startMenuMusic();
      _checkSave();
    });
  }

  void _continue() {
    HxAudio.instance.click();
    HxAudio.instance.startGameMusic();
    HxSettings.instance.loadGame().then((raw) {
      var vsAi = true;
      if (raw != null) {
        try {
          final j = jsonDecode(raw) as Map<String, dynamic>;
          vsAi = j['vsAi'] as bool? ?? true;
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) => HexGameScreen(vsAi: vsAi, restore: true)))
          .then((_) {
        HxAudio.instance.startMenuMusic();
        _checkSave();
      });
    });
  }

  void _open(Widget screen) {
    HxAudio.instance.click();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final set = HxSettings.instance;
    final theme = set.theme;
    return Scaffold(
      body: WorkbenchBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Game logo.
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: HxTheme.terracotta, width: 2.5),
                      boxShadow: HxTheme.plaqueShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/hex_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text('HEX',
                      textAlign: TextAlign.center,
                      style: HxTheme.title(56, HxTheme.terracotta)),
                  const SizedBox(height: 2),
                  Text('the ceramic connection game',
                      style: HxTheme.body.copyWith(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: HxTheme.carved.withValues(alpha: 0.8))),
                  const SizedBox(height: 24),
                  if (_hasSave) ...[
                    ClayButton(
                        label: 'Continue',
                        glazeColor: HxTheme.indigo,
                        onTap: _continue),
                    const SizedBox(height: 14),
                  ],
                  ClayButton(label: 'Play vs AI', onTap: () => _play(true)),
                  const SizedBox(height: 14),
                  ClayButton(
                      label: 'Two Players', onTap: () => _play(false)),
                  const SizedBox(height: 14),
                  ClayButton(
                      label: 'Themes', onTap: () => _open(const ThemesScreen())),
                  const SizedBox(height: 14),
                  ClayButton(
                      label: set.isPro ? 'Hex PRO ✦' : 'Hex PRO',
                      glazeColor: HxTheme.terracotta,
                      onTap: () => _open(ProScreen(store: hexStore))),
                  const SizedBox(height: 14),
                  ClayButton(
                    label: 'Settings',
                    fontSize: 17,
                    onTap: () => _open(const SettingsScreen()),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: HxTheme.walnutSign(radius: 12),
                    child: Text(
                      '${set.nameOf(0)} ${set.terracottaWins}  ·  ${set.nameOf(1)} ${set.indigoWins}  ·  ${set.gamesPlayed} fired',
                      style: HxTheme.body.copyWith(
                          color: HxTheme.cream, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Decorative scattered tiles along the bottom.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlazedHexIcon(
                          size: 30, player: 1, glaze: theme.glaze(1)),
                      const SizedBox(width: 26),
                      GlazedHexIcon(
                          size: 22, player: 0, glaze: theme.glaze(0)),
                      const SizedBox(width: 26),
                      GlazedHexIcon(
                          size: 30, player: 0, glaze: theme.glaze(0)),
                      const SizedBox(width: 26),
                      GlazedHexIcon(
                          size: 22, player: 1, glaze: theme.glaze(1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== THEMES ====================

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});
  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  final _set = HxSettings.instance;

  void _pickTheme(String id) async {
    if (!_set.isPro && !HxThemes.isFree(id)) {
      HxAudio.instance.invalid();
      _showProNudge('Themes');
      return;
    }
    await _set.setTheme(id);
    HxAudio.instance.click();
    setState(() {});
  }

  void _pickStyle(int i) async {
    if (!_set.isPro && !HxTileStyles.isFree(i)) {
      HxAudio.instance.invalid();
      _showProNudge('Tile styles');
      return;
    }
    await _set.setTileStyle(i);
    HxAudio.instance.click();
    setState(() {});
  }

  void _showProNudge(String what) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: HxTheme.biscuit,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PRO only',
                  style: HxTheme.plaqueTitle.copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                '$what beyond the free set need Hex PRO — one purchase, yours forever.',
                style: HxTheme.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClayButton(
                label: 'See Hex PRO',
                glazeColor: HxTheme.terracotta,
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProScreen(store: hexStore)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _set.theme;
    return Scaffold(
      body: WorkbenchBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    TokenButton(
                        icon: Icons.arrow_back,
                        size: 48,
                        onTap: () {
                          HxAudio.instance.click();
                          Navigator.of(context).pop();
                        }),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: HxTheme.walnutSign(),
                        child: Text('Kiln Themes',
                            style: HxTheme.title(22, HxTheme.cream)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 10),
                  children: [
                    Text('Glaze themes',
                        style: HxTheme.plaqueTitle.copyWith(fontSize: 17)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.7,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: HxThemes.all.length +
                          (_set.isPro ? 1 : 0), // + custom slot for Pro
                      itemBuilder: (ctx, i) {
                        if (i == HxThemes.all.length) {
                          return _themeCard(
                              id: 'custom',
                              name: 'My Creation',
                              custom: true,
                              theme: theme);
                        }
                        final t = HxThemes.all[i];
                        return _themeCard(
                            id: t.id, name: t.name, themeDef: t, theme: theme);
                      },
                    ),
                    const SizedBox(height: 18),
                    Text('Tile glaze styles',
                        style: HxTheme.plaqueTitle.copyWith(fontSize: 17)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: HxTileStyles.names.length,
                      itemBuilder: (ctx, i) {
                        final locked =
                            !_set.isPro && !HxTileStyles.isFree(i);
                        final selected = _set.tileStyle == i;
                        return GestureDetector(
                          onTap: () => _pickStyle(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: selected
                                  ? LinearGradient(colors: [
                                      Color.lerp(HxTheme.terracotta,
                                          Colors.white, 0.25)!,
                                      HxTheme.terracotta,
                                      Color.lerp(HxTheme.terracotta,
                                          Colors.black, 0.25)!,
                                    ])
                                  : null,
                              color: selected
                                  ? null
                                  : Colors.black.withValues(alpha: 0.25),
                              border: Border.all(
                                color: selected
                                    ? HxTheme.cream.withValues(alpha: 0.7)
                                    : Colors.black38,
                                width: selected ? 2 : 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${HxTileStyles.names[i]}${locked ? ' ✦' : ''}',
                                textAlign: TextAlign.center,
                                style: HxTheme.body.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? HxTheme.cream
                                      : HxTheme.cream
                                          .withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeCard(
      {required String id,
      required String name,
      HxThemeDef? themeDef,
      required HxThemeDef theme,
      bool custom = false}) {
    final selected = _set.themeId == id;
    final locked = !_set.isPro && !custom && !HxThemes.isFree(id);
    final def = themeDef ?? HxThemeDef.customFrom(_set.customColors);
    return GestureDetector(
      onTap: custom
          ? () {
              HxAudio.instance.click();
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => const CustomThemeScreen()))
                  .then((_) => setState(() {}));
            }
          : () => _pickTheme(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [def.walnut, def.walnutDeep],
          ),
          border: Border.all(
            color: selected
                ? HxTheme.cream.withValues(alpha: 0.8)
                : Colors.black45,
            width: selected ? 2.5 : 1.2,
          ),
          boxShadow: selected ? HxTheme.plaqueShadow : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlazedHexIcon(size: 30, player: 0, glaze: def.glaze(0)),
                const SizedBox(width: 8),
                GlazedHexIcon(size: 30, player: 1, glaze: def.glaze(1)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$name${locked ? ' ✦' : ''}',
              textAlign: TextAlign.center,
              style: HxTheme.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: locked
                    ? HxTheme.cream.withValues(alpha: 0.5)
                    : HxTheme.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SETTINGS ====================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final audio = HxAudio.instance;
    final set = HxSettings.instance;
    final theme = set.theme;
    return Scaffold(
      body: WorkbenchBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            children: [
              Row(
                children: [
                  TokenButton(
                      icon: Icons.arrow_back,
                      size: 48,
                      onTap: () {
                        audio.click();
                        Navigator.of(context).pop();
                      }),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: HxTheme.walnutSign(),
                      child: Text('Workshop Settings',
                          style: HxTheme.title(22, HxTheme.cream)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _plaqueRow(
                  'Music',
                  PegToggle(
                      value: audio.musicOn,
                      pegColor: HxTheme.terracotta,
                      onChanged: (v) async {
                        await audio.setMusic(v);
                        await set.setMusicOn(v);
                        setState(() {});
                      })),
              _plaqueRow(
                  'Sound FX',
                  PegToggle(
                      value: audio.sfxOn,
                      pegColor: HxTheme.indigo,
                      onChanged: (v) async {
                        await audio.setSfx(v);
                        await set.setSfxOn(v);
                        if (v) audio.click();
                        setState(() {});
                      })),
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: HxTheme.clayPlaque(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Volume',
                        style: HxTheme.plaqueTitle.copyWith(fontSize: 16)),
                    Slider(
                      value: audio.volume,
                      activeColor: HxTheme.terracotta,
                      inactiveColor: HxTheme.walnut,
                      onChanged: (v) async {
                        await audio.setVolume(v);
                        await set.setVolume(v);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              // Renameable players (both slots).
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: HxTheme.clayPlaque(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Player names',
                        style: HxTheme.plaqueTitle.copyWith(fontSize: 16)),
                    const SizedBox(height: 10),
                    for (int p = 0; p < 2; p++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            GlazedHexIcon(
                                size: 30, player: p, glaze: theme.glaze(p)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('name$p'),
                                initialValue: set.nameOf(p),
                                maxLength: 16,
                                style: HxTheme.body
                                    .copyWith(fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  counterText: '',
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: HxTheme.cream
                                      .withValues(alpha: 0.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onFieldSubmitted: (v) async {
                                  await set.setPlayerName(p, v);
                                  audio.click();
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              _tileGroup(
                'Board size',
                HxSettings.boardSizes
                    .map((s) => TileChip(
                          label: '$s×$s',
                          selected: set.boardSize == s,
                          glazeColor: HxTheme.terracotta,
                          onTap: () async {
                            await set.setBoardSize(s);
                            audio.click();
                            setState(() {});
                          },
                        ))
                    .toList(),
              ),
              _tileGroup(
                'AI difficulty',
                List.generate(
                    3,
                    (i) => TileChip(
                          label:
                              '${HxSettings.difficulties[i]}${i == 2 && !set.isPro ? ' ✦' : ''}',
                          selected: set.difficulty == i,
                          glazeColor: HxTheme.indigo,
                          onTap: () async {
                            if (i == 2 && !set.isPro) {
                              audio.invalid();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Master AI needs Hex PRO — see the PRO screen.',
                                      style: HxTheme.body.copyWith(
                                          color: HxTheme.cream)),
                                  backgroundColor: HxTheme.walnut,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            await set.setDifficulty(i);
                            audio.click();
                            setState(() {});
                          },
                        )),
              ),
              _tileGroup(
                'Your color (vs AI)',
                List.generate(
                    2,
                    (i) => TileChip(
                          label: set.nameOf(i),
                          selected: set.humanColor == i,
                          glazeColor:
                              i == 0 ? HxTheme.terracotta : HxTheme.indigo,
                          onTap: () async {
                            await set.setHumanColor(i);
                            audio.click();
                            setState(() {});
                          },
                        )),
              ),
              _plaqueRow(
                  'Pie rule (swap)',
                  PegToggle(
                      value: set.pieRule,
                      pegColor: HxTheme.terracotta,
                      onChanged: (v) async {
                        await set.setPieRule(v);
                        audio.click();
                        setState(() {});
                      })),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: HxTheme.clayPlaque(),
                child: Text(
                  '${set.nameOf(0)} connects top to bottom. ${set.nameOf(1)} connects left to right. '
                  'After the opening tile, ${set.nameOf(1)} may swap colors instead of playing. '
                  'Every board holds exactly one winner — draws are impossible.',
                  style: HxTheme.body.copyWith(fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plaqueRow(String label, Widget trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: HxTheme.clayPlaque(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: HxTheme.plaqueTitle.copyWith(fontSize: 16)),
          trailing,
        ],
      ),
    );
  }

  Widget _tileGroup(String label, List<Widget> chips) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: HxTheme.clayPlaque(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HxTheme.plaqueTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < chips.length; i++) ...[
                Expanded(child: chips[i]),
                if (i < chips.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
