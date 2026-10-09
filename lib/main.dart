import 'dart:convert';

import 'package:flutter/material.dart';
import 'audio.dart';
import 'hex_theme.dart';
import 'game_screen.dart';
import 'settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HxAudio.instance.init();
  await HxSettings.instance.init();
  runApp(const HexApp());
}

class HexApp extends StatelessWidget {
  const HexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: HxTheme.oak,
        fontFamily: HxTheme.bodyFamily,
      ),
      home: const MainMenu(),
    );
  }
}

// ==================== MAIN MENU ====================

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with WidgetsBindingObserver {
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HxAudio.instance.playMusic('audio/music_menu.wav');
    _checkSave();
  }

  Future<void> _checkSave() async {
    _hasSave = await HxSettings.instance.hasSave;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      HxAudio.instance.stopMusic();
    } else if (state == AppLifecycleState.resumed) {
      HxAudio.instance.playMusic('audio/music_menu.wav');
      _checkSave();
    }
  }

  void _play(bool vsAi) {
    HxAudio.instance.click();
    HxAudio.instance.playMusic('audio/music_game.wav');
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => HexGameScreen(vsAi: vsAi)))
        .then((_) {
      HxAudio.instance.playMusic('audio/music_menu.wav');
      _checkSave();
    });
  }

  void _continue() {
    HxAudio.instance.click();
    HxAudio.instance.playMusic('audio/music_game.wav');
    // The save records which mode it was.
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
        HxAudio.instance.playMusic('audio/music_menu.wav');
        _checkSave();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final set = HxSettings.instance;
    return Scaffold(
      body: WorkbenchBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chunky glazed hex-tile title lettering.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      GlazedHexIcon(size: 54, player: 0),
                      SizedBox(width: 10),
                      GlazedHexIcon(size: 54, player: 1),
                      SizedBox(width: 10),
                      GlazedHexIcon(size: 54, player: 0),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('HEX',
                      textAlign: TextAlign.center,
                      style: HxTheme.title(64, HxTheme.terracotta)),
                  const SizedBox(height: 4),
                  Text('the ceramic connection game',
                      style: HxTheme.body.copyWith(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: HxTheme.carved.withValues(alpha: 0.8))),
                  const SizedBox(height: 30),
                  if (_hasSave) ...[
                    ClayButton(
                        label: 'Continue',
                        glazeColor: HxTheme.indigo,
                        onTap: _continue),
                    const SizedBox(height: 14),
                  ],
                  ClayButton(
                      label: 'Play vs AI', onTap: () => _play(true)),
                  const SizedBox(height: 14),
                  ClayButton(
                      label: 'Two Players', onTap: () => _play(false)),
                  const SizedBox(height: 14),
                  ClayButton(
                    label: 'Settings',
                    fontSize: 17,
                    onTap: () {
                      HxAudio.instance.click();
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => const SettingsScreen()))
                          .then((_) => setState(() {}));
                    },
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: HxTheme.walnutSign(radius: 12),
                    child: Text(
                      'Terracotta ${set.terracottaWins}  ·  Indigo ${set.indigoWins}  ·  ${set.gamesPlayed} fired',
                      style: HxTheme.body.copyWith(
                          color: HxTheme.cream, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Decorative scattered tiles along the bottom.
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlazedHexIcon(size: 30, player: 1),
                      SizedBox(width: 26),
                      GlazedHexIcon(size: 22, player: 0),
                      SizedBox(width: 26),
                      GlazedHexIcon(size: 30, player: 0),
                      SizedBox(width: 26),
                      GlazedHexIcon(size: 22, player: 1),
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
                        if (v) {
                          audio.playMusic('audio/music_menu.wav');
                        }
                        setState(() {});
                      })),
              _plaqueRow(
                  'Sound FX',
                  PegToggle(
                      value: audio.sfxOn,
                      pegColor: HxTheme.indigo,
                      onChanged: (v) async {
                        await audio.setSfx(v);
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
                        setState(() {});
                      },
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
                          label: HxSettings.difficulties[i],
                          selected: set.difficulty == i,
                          glazeColor: HxTheme.indigo,
                          onTap: () async {
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
                          label: HxSettings.playerNames[i],
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
                  'Terracotta connects top to bottom. Indigo connects left to right. '
                  'After the opening tile, Indigo may swap colors instead of playing. '
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
          Text(label,
              style: HxTheme.plaqueTitle.copyWith(fontSize: 16)),
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
