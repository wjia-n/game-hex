import 'package:flutter/material.dart';

import 'audio.dart';
import 'hex_theme.dart';
import 'settings.dart';

/// Custom theme creator: pick glaze/wood colors from a curated kiln palette.
/// PRO feature (free tier never reaches this screen).
class CustomThemeScreen extends StatefulWidget {
  const CustomThemeScreen({super.key});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const _rows = [
    ('terraHi', 'Terracotta highlight'),
    ('terra', 'Terracotta glaze'),
    ('terraLo', 'Terracotta shadow'),
    ('indigoHi', 'Indigo highlight'),
    ('indigo', 'Indigo glaze'),
    ('indigoLo', 'Indigo shadow'),
    ('biscuit', 'Clay plaques'),
    ('walnut', 'Board tray wood'),
    ('oak', 'Workbench wood'),
  ];

  /// Curated kiln palette — warm fired tones only, no neon.
  static const _swatches = [
    0xFFC96F4A, 0xFFE08B60, 0xFF9C4E2E, 0xFFD4692E, 0xFFB85A24,
    0xFF4E6E8E, 0xFF6E93B5, 0xFF354E66, 0xFF2E4E82, 0xFF1C3256,
    0xFF93B89B, 0xFF5F8A7D, 0xFF5F7F4C, 0xFF9A8446, 0xFFE09A34,
    0xFFD9B48F, 0xFFEACBA6, 0xFFB78F63, 0xFF8A6B4F, 0xFF3A2A1E,
    0xFF2E1F16, 0xFF6E4560, 0xFF8A6244, 0xFF36363A,
  ];

  final _set = HxSettings.instance;

  void _pick(String key) {
    HxAudio.instance.click();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: HxTheme.biscuit,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose color',
                  style: HxTheme.plaqueTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final c in _swatches)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _set.setCustomColor(key, c);
                        HxAudio.instance.click();
                        setState(() {});
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _set.customColors[key] == c
                                  ? HxTheme.cream
                                  : Colors.black26,
                              width: _set.customColors[key] == c ? 3 : 1.5),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black38,
                                blurRadius: 4,
                                offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        child: Text('Theme Creator',
                            style: HxTheme.title(22, HxTheme.cream)),
                      ),
                    ),
                  ],
                ),
              ),
              // Live preview tiles.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PreviewTile(colors: _set.customColors, player: 0),
                    const SizedBox(width: 18),
                    _PreviewTile(colors: _set.customColors, player: 1),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 8),
                  itemCount: _rows.length,
                  itemBuilder: (ctx, i) {
                    final key = _rows[i].$1;
                    final label = _rows[i].$2;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: HxTheme.clayPlaque(radius: 12),
                      child: ListTile(
                        title: Text(label,
                            style: HxTheme.plaqueTitle.copyWith(fontSize: 16)),
                        trailing: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(_set.customColors[key] ?? 0xFF808080),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: HxTheme.carved, width: 1.5),
                          ),
                        ),
                        onTap: () => _pick(key),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                child: ClayButton(
                  label: 'Use my creation',
                  glazeColor: HxTheme.terracotta,
                  onTap: () {
                    Navigator.of(context).pop();
                    _set.setTheme('custom');
                    HxAudio.instance.click();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final Map<String, int> colors;
  final int player;
  const _PreviewTile({required this.colors, required this.player});

  @override
  Widget build(BuildContext context) {
    final hi = Color(colors[player == 0 ? 'terraHi' : 'indigoHi'] ?? 0xFF808080);
    final mid =
        Color(colors[player == 0 ? 'terra' : 'indigo'] ?? 0xFF808080);
    final lo =
        Color(colors[player == 0 ? 'terraLo' : 'indigoLo'] ?? 0xFF808080);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: [hi, mid, lo],
        ),
        border: Border.all(color: lo, width: 2),
        boxShadow: HxTheme.plaqueShadow,
      ),
    );
  }
}
