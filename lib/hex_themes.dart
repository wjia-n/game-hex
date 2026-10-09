import 'package:flutter/material.dart';

/// Theme, tile-style and accent catalog for Hex (Atelier Hex).
///
/// Every theme stays inside the ceramic-workshop material world — fired clay,
/// wood, kiln shadow — the variety comes from different glaze pairs, woods
/// and workshop tones. No neon, no flat digital look.
class HxThemeDef {
  final String id;
  final String name;
  final bool pro;
  final Color terraHi;
  final Color terra;
  final Color terraLo;
  final Color indigoHi;
  final Color indigo;
  final Color indigoLo;
  final Color biscuit;
  final Color biscuitHi;
  final Color biscuitLo;
  final Color cream;
  final Color walnut;
  final Color walnutDeep;
  final Color oak;
  final Color oakDeep;
  final Color carved;

  const HxThemeDef({
    required this.id,
    required this.name,
    required this.pro,
    required this.terraHi,
    required this.terra,
    required this.terraLo,
    required this.indigoHi,
    required this.indigo,
    required this.indigoLo,
    required this.biscuit,
    required this.biscuitHi,
    required this.biscuitLo,
    required this.cream,
    required this.walnut,
    required this.walnutDeep,
    required this.oak,
    required this.oakDeep,
    required this.carved,
  });

  (Color hi, Color mid, Color lo) glaze(int player) => player == 0
      ? (terraHi, terra, terraLo)
      : (indigoHi, indigo, indigoLo);

  Map<String, int> toCustomColors() => {
        'terraHi': terraHi.toARGB32(),
        'terra': terra.toARGB32(),
        'terraLo': terraLo.toARGB32(),
        'indigoHi': indigoHi.toARGB32(),
        'indigo': indigo.toARGB32(),
        'indigoLo': indigoLo.toARGB32(),
        'biscuit': biscuit.toARGB32(),
        'walnut': walnut.toARGB32(),
        'oak': oak.toARGB32(),
      };

  static HxThemeDef customFrom(Map<String, int> c) {
    Color v(String k, int dflt) => Color(c[k] ?? dflt);
    final base = HxThemes.all[0];
    return HxThemeDef(
      id: 'custom',
      name: 'My Creation',
      pro: true,
      terraHi: v('terraHi', 0xFFE08B60),
      terra: v('terra', 0xFFC96F4A),
      terraLo: v('terraLo', 0xFF9C4E2E),
      indigoHi: v('indigoHi', 0xFF6E93B5),
      indigo: v('indigo', 0xFF4E6E8E),
      indigoLo: v('indigoLo', 0xFF354E66),
      biscuit: v('biscuit', 0xFFD9B48F),
      biscuitHi: Color.lerp(v('biscuit', 0xFFD9B48F), Colors.white, 0.18)!,
      biscuitLo: Color.lerp(v('biscuit', 0xFFD9B48F), Colors.black, 0.22)!,
      cream: base.cream,
      walnut: v('walnut', 0xFF3A2A1E),
      walnutDeep: Color.lerp(v('walnut', 0xFF3A2A1E), Colors.black, 0.35)!,
      oak: v('oak', 0xFF8A6B4F),
      oakDeep: Color.lerp(v('oak', 0xFF8A6B4F), Colors.black, 0.18)!,
      carved: base.carved,
    );
  }
}

class HxThemes {
  /// First 4 are the FREE starter themes; the rest are PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'ember',
    'riverstone',
    'harvest',
  ];

  static const List<HxThemeDef> all = [
    // ---- free ----
    HxThemeDef(
      id: 'classic',
      name: 'Classic Kiln',
      pro: false,
      terraHi: Color(0xFFE08B60),
      terra: Color(0xFFC96F4A),
      terraLo: Color(0xFF9C4E2E),
      indigoHi: Color(0xFF6E93B5),
      indigo: Color(0xFF4E6E8E),
      indigoLo: Color(0xFF354E66),
      biscuit: Color(0xFFD9B48F),
      biscuitHi: Color(0xFFEACBA6),
      biscuitLo: Color(0xFFB78F63),
      cream: Color(0xFFEFE3D2),
      walnut: Color(0xFF3A2A1E),
      walnutDeep: Color(0xFF241812),
      oak: Color(0xFF8A6B4F),
      oakDeep: Color(0xFF6E5439),
      carved: Color(0xFF2E2015),
    ),
    HxThemeDef(
      id: 'ember',
      name: 'Ember Glow',
      pro: false,
      terraHi: Color(0xFFF09A5A),
      terra: Color(0xFFD4692E),
      terraLo: Color(0xFF9A4218),
      indigoHi: Color(0xFF8A6A5A),
      indigo: Color(0xFF5E463C),
      indigoLo: Color(0xFF3A2B24),
      biscuit: Color(0xFFE0B78E),
      biscuitHi: Color(0xFFF2D2AE),
      biscuitLo: Color(0xFFB98F62),
      cream: Color(0xFFF7E8D4),
      walnut: Color(0xFF2E1F16),
      walnutDeep: Color(0xFF1A1009),
      oak: Color(0xFF7A5A3C),
      oakDeep: Color(0xFF5E452D),
      carved: Color(0xFF241610),
    ),
    HxThemeDef(
      id: 'riverstone',
      name: 'Riverstone',
      pro: false,
      terraHi: Color(0xFFB9C4C9),
      terra: Color(0xFF8A979E),
      terraLo: Color(0xFF5E6B72),
      indigoHi: Color(0xFF5F87A8),
      indigo: Color(0xFF3D617F),
      indigoLo: Color(0xFF274357),
      biscuit: Color(0xFFCDBFA8),
      biscuitHi: Color(0xFFE2D6BE),
      biscuitLo: Color(0xFFA3916F),
      cream: Color(0xFFF2EBDC),
      walnut: Color(0xFF3B322A),
      walnutDeep: Color(0xFF242019),
      oak: Color(0xFF8C7F68),
      oakDeep: Color(0xFF6E6450),
      carved: Color(0xFF2A251D),
    ),
    HxThemeDef(
      id: 'harvest',
      name: 'Harvest Wheat',
      pro: false,
      terraHi: Color(0xFFE8A86B),
      terra: Color(0xFFC97F3F),
      terraLo: Color(0xFF96581F),
      indigoHi: Color(0xFF7FA08A),
      indigo: Color(0xFF57785F),
      indigoLo: Color(0xFF3A5442),
      biscuit: Color(0xFFE8CFA0),
      biscuitHi: Color(0xFFF7E4BC),
      biscuitLo: Color(0xFFC0A06A),
      cream: Color(0xFFFBF0DA),
      walnut: Color(0xFF4A3524),
      walnutDeep: Color(0xFF2E2114),
      oak: Color(0xFF9A7A50),
      oakDeep: Color(0xFF7A5F3C),
      carved: Color(0xFF33230F),
    ),
    // ---- pro ----
    HxThemeDef(
      id: 'celadon',
      name: 'Celadon',
      pro: true,
      terraHi: Color(0xFFBFD8C4),
      terra: Color(0xFF93B89B),
      terraLo: Color(0xFF638A6D),
      indigoHi: Color(0xFF8FB4A8),
      indigo: Color(0xFF5F8A7D),
      indigoLo: Color(0xFF3E5F56),
      biscuit: Color(0xFFD8CDB4),
      biscuitHi: Color(0xFFEDE3C8),
      biscuitLo: Color(0xFFAF9F7C),
      cream: Color(0xFFF4EDDE),
      walnut: Color(0xFF2E2A22),
      walnutDeep: Color(0xFF1B1913),
      oak: Color(0xFF7E7260),
      oakDeep: Color(0xFF625847),
      carved: Color(0xFF24211A),
    ),
    HxThemeDef(
      id: 'raku',
      name: 'Raku Fire',
      pro: true,
      terraHi: Color(0xFFE08A4A),
      terra: Color(0xFFB85A24),
      terraLo: Color(0xFF7A3712),
      indigoHi: Color(0xFF5A5A5E),
      indigo: Color(0xFF36363A),
      indigoLo: Color(0xFF1E1E22),
      biscuit: Color(0xFFB99A72),
      biscuitHi: Color(0xFFD4B58C),
      biscuitLo: Color(0xFF8F6F4C),
      cream: Color(0xFFEFE0C8),
      walnut: Color(0xFF201612),
      walnutDeep: Color(0xFF100B08),
      oak: Color(0xFF5E4A34),
      oakDeep: Color(0xFF483824),
      carved: Color(0xFF1E140E),
    ),
    HxThemeDef(
      id: 'cobalt',
      name: 'Cobalt Wash',
      pro: true,
      terraHi: Color(0xFFF0E2C8),
      terra: Color(0xFFD9C29A),
      terraLo: Color(0xFFA98F62),
      indigoHi: Color(0xFF4A6FAE),
      indigo: Color(0xFF2E4E82),
      indigoLo: Color(0xFF1C3256),
      biscuit: Color(0xFFE4D4B8),
      biscuitHi: Color(0xFFF5E8CE),
      biscuitLo: Color(0xFFBCA67E),
      cream: Color(0xFFF9F1E2),
      walnut: Color(0xFF3A2C20),
      walnutDeep: Color(0xFF241A12),
      oak: Color(0xFF8A6E4E),
      oakDeep: Color(0xFF6E573C),
      carved: Color(0xFF2E2114),
    ),
    HxThemeDef(
      id: 'sandstone',
      name: 'Sandstone',
      pro: true,
      terraHi: Color(0xFFE8B48A),
      terra: Color(0xFFCE8A5A),
      terraLo: Color(0xFF9A6136),
      indigoHi: Color(0xFFA89880),
      indigo: Color(0xFF7A6A52),
      indigoLo: Color(0xFF544834),
      biscuit: Color(0xFFEAD9B8),
      biscuitHi: Color(0xFFFBEED2),
      biscuitLo: Color(0xFFC6AE82),
      cream: Color(0xFFFCF4E4),
      walnut: Color(0xFF42311F),
      walnutDeep: Color(0xFF2A1E12),
      oak: Color(0xFF967950),
      oakDeep: Color(0xFF765D3C),
      carved: Color(0xFF352512),
    ),
    HxThemeDef(
      id: 'moss',
      name: 'Moss & Lichen',
      pro: true,
      terraHi: Color(0xFFC4B06A),
      terra: Color(0xFF9A8446),
      terraLo: Color(0xFF6B5A2A),
      indigoHi: Color(0xFF8AA86E),
      indigo: Color(0xFF5F7F4C),
      indigoLo: Color(0xFF3E5730),
      biscuit: Color(0xFFCDBB96),
      biscuitHi: Color(0xFFE4D5B0),
      biscuitLo: Color(0xFFA39068),
      cream: Color(0xFFF1EAD8),
      walnut: Color(0xFF33291D),
      walnutDeep: Color(0xFF201A12),
      oak: Color(0xFF7E6C4C),
      oakDeep: Color(0xFF63553A),
      carved: Color(0xFF28200F),
    ),
    HxThemeDef(
      id: 'plum',
      name: 'Plum & Amber',
      pro: true,
      terraHi: Color(0xFFF0B25A),
      terra: Color(0xFFD18A2E),
      terraLo: Color(0xFF96601A),
      indigoHi: Color(0xFF9A6A8A),
      indigo: Color(0xFF6E4560),
      indigoLo: Color(0xFF4A2C40),
      biscuit: Color(0xFFD8BC9E),
      biscuitHi: Color(0xFFEDD4B6),
      biscuitLo: Color(0xFFAE8C66),
      cream: Color(0xFFF6EAD8),
      walnut: Color(0xFF32241E),
      walnutDeep: Color(0xFF1F1510),
      oak: Color(0xFF7E6248),
      oakDeep: Color(0xFF634C36),
      carved: Color(0xFF2A1C12),
    ),
    HxThemeDef(
      id: 'ironstone',
      name: 'Ironstone',
      pro: true,
      terraHi: Color(0xFFB08A6A),
      terra: Color(0xFF8A6244),
      terraLo: Color(0xFF5E4028),
      indigoHi: Color(0xFF7E8A94),
      indigo: Color(0xFF56616C),
      indigoLo: Color(0xFF37414A),
      biscuit: Color(0xFFC4B49A),
      biscuitHi: Color(0xFFDACBB0),
      biscuitLo: Color(0xFF9C8A6E),
      cream: Color(0xFFEFE8D8),
      walnut: Color(0xFF2C2622),
      walnutDeep: Color(0xFF1B1814),
      oak: Color(0xFF6E6257),
      oakDeep: Color(0xFF574C43),
      carved: Color(0xFF241F1A),
    ),
    HxThemeDef(
      id: 'honey',
      name: 'Wild Honey',
      pro: true,
      terraHi: Color(0xFFF5C86E),
      terra: Color(0xFFE09A34),
      terraLo: Color(0xFFA96E1C),
      indigoHi: Color(0xFF8A7A5A),
      indigo: Color(0xFF5E523C),
      indigoLo: Color(0xFF403824),
      biscuit: Color(0xFFE8D0A2),
      biscuitHi: Color(0xFFF9E6BC),
      biscuitLo: Color(0xFFC0A26E),
      cream: Color(0xFFFBF2DC),
      walnut: Color(0xFF3C2E1C),
      walnutDeep: Color(0xFF261C10),
      oak: Color(0xFF8C7148),
      oakDeep: Color(0xFF6E5836),
      carved: Color(0xFF30220E),
    ),
    HxThemeDef(
      id: 'midnight',
      name: 'Midnight Kiln',
      pro: true,
      terraHi: Color(0xFFE08A4A),
      terra: Color(0xFFB85A24),
      terraLo: Color(0xFF7A3712),
      indigoHi: Color(0xFF6A8AA8),
      indigo: Color(0xFF45627E),
      indigoLo: Color(0xFF2A3E54),
      biscuit: Color(0xFF8A7A64),
      biscuitHi: Color(0xFFA39276),
      biscuitLo: Color(0xFF64553F),
      cream: Color(0xFFE8DCC4),
      walnut: Color(0xFF171310),
      walnutDeep: Color(0xFF0C0A08),
      oak: Color(0xFF4A3E30),
      oakDeep: Color(0xFF382E22),
      carved: Color(0xFF14100C),
    ),
  ];

  static HxThemeDef byId(String id, {Map<String, int>? custom}) {
    if (id == 'custom') return HxThemeDef.customFrom(custom ?? {});
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all[0];
  }

  static bool isFree(String id) => freeThemeIds.contains(id);
}

/// Tile glaze styles — painter variations on the same physical tile.
/// Index persisted in settings; PRO unlocks styles 4+.
class HxTileStyles {
  static const List<String> names = [
    'Classic Glaze', // 0 free
    'Speckled Stoneware', // 1 free
    'Matte Bisque', // 2 free
    'Ring Inlay', // 3 free
    'Raku Crackle', // 4 pro
    'Iron Spots', // 5 pro
    'Dipped Two-Tone', // 6 pro
    'Ash Dusted', // 7 pro
    'Carved Groove', // 8 pro
    'Salt Glaze', // 9 pro
  ];

  static const int freeCount = 4;

  static bool isFree(int i) => i < freeCount;
}
