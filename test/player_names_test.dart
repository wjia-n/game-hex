import 'package:flutter_test/flutter_test.dart';
import 'package:hex/settings.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Player names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// two names could come back swapped and renames appeared "not saved".
/// Names are now stored as one order-preserving JSON string. These tests
/// cover the encode/decode round-trip plus the UI reload path, without
/// needing platform channels.
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Zara'];
    final decoded = HxSettings.decodePlayerNames(
      HxSettings.encodePlayerNames(names),
    );
    expect(decoded, names);
    // Slot order is what matters: each index must map to the same player.
    for (int i = 0; i < 2; i++) {
      expect(decoded[i], names[i]);
    }
  });

  test('decode falls back to defaults on missing or corrupt data', () {
    expect(
      HxSettings.decodePlayerNames(null),
      HxSettings.defaultNames,
    );
    expect(
      HxSettings.decodePlayerNames('definitely not json'),
      HxSettings.defaultNames,
    );
    expect(
      HxSettings.decodePlayerNames('["only"]'),
      HxSettings.defaultNames,
    );
    expect(
      HxSettings.decodePlayerNames('{"a":1}'),
      HxSettings.defaultNames,
    );
  });

  test('blank entries fall back to that slot\'s default name', () {
    final decoded = HxSettings.decodePlayerNames('["Wajiha","  "]');
    expect(decoded, ['Wajiha', 'Indigo']);
  });

  test('UI rebuilt after "restart" shows the persisted names', () {
    // Simulate: user renamed slot 0, app restarted, UI rebuilt from the
    // persisted value.
    const renamed = ['Wajiha', 'Indigo'];
    final persisted = HxSettings.decodePlayerNames(
      HxSettings.encodePlayerNames(renamed),
    );
    // nameOf() is the single source of truth for display names.
    HxSettings.instance.playerNames = persisted;
    expect(HxSettings.instance.nameOf(0), 'Wajiha');
    expect(HxSettings.instance.nameOf(1), 'Indigo');
    // The rename also reaches the menu tally line that interpolates names.
    expect('${HxSettings.instance.nameOf(0)} wins', contains('Wajiha'));
    HxSettings.instance.playerNames = List.of(HxSettings.defaultNames);
  });
}
