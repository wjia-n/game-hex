import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'audio.dart';
import 'hex_theme.dart';
import 'iap_service.dart';
import 'settings.dart';

/// Hex PRO: Free-vs-Pro comparison, real purchase, restore, and tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final StoreService store;
  const ProScreen({super.key, required this.store});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  @override
  void initState() {
    super.initState();
        widget.store.lastThanks.addListener(_onThanks);
  }


  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    HxAudio.instance.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: HxTheme.body.copyWith(color: HxTheme.cream)),
        backgroundColor: HxTheme.walnut,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
        widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // iOS-only Gold Star screen. Android build below is untouched.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gold Star'), centerTitle: true),
        body: SafeArea(
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.store.starOwned,
            builder: (_, owned, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('\u2b50', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text(owned ? 'Gold Star unlocked!' : 'Gold Star',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('The game stays fully unlocked. The Gold Star is a cosmetic badge of support.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    if (owned)
                      const Text('\u2b50 Gold Star badge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                    else if (widget.store.starProduct != null)
                      ElevatedButton(
                        onPressed: () => widget.store.buyStar(widget.store.starProduct!),
                        child: Text('\u2b50 Gold Star — ${widget.store.starProduct!.price}'),
                      )
                    else
                      Text(widget.store.error ?? 'Loading…'),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => widget.store.restore(), child: const Text('Restore purchase')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final set = HxSettings.instance;
    final store = widget.store;
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
                        child: Text('Hex PRO',
                            style: HxTheme.title(22, HxTheme.cream)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  child: Column(
                    children: [
                      _ComparisonCard(isPro: set.isPro),
                      const SizedBox(height: 16),
                      _BuyCard(store: store),
                      const SizedBox(height: 16),
                      _TipsCard(store: store),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.
class _ComparisonCard extends StatelessWidget {
  final bool isPro;
  const _ComparisonCard({required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Complete Hex game', true, true),
      ('All official rules incl. pie rule', true, true),
      ('Board sizes 7 · 9 · 11 · 13', true, true),
      ('Gentle & Steady AI', true, true),
      ('2-player pass-and-play', true, true),
      ('Renameable players', true, true),
      ('Music & sound effects', true, true),
      ('Kiln themes', '4', '13'),
      ('Tile glaze styles', '4', '10'),
      ('Custom theme creator', false, true),
      ('Master AI', false, true),
      ('Exclusive board accents', false, true),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xD84E3A28), Color(0xE6241812)],
        ),
        border: Border.all(color: HxTheme.terracotta, width: 2),
      ),
      child: Column(
        children: [
          Text('Free vs PRO', style: HxTheme.title(20, HxTheme.cream)),
          const SizedBox(height: 4),
          Text(
            'One purchase. Yours forever.',
            style: HxTheme.body.copyWith(
                color: HxTheme.cream.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                  flex: 2,
                  child: Text('FREE',
                      style: HxTheme.body.copyWith(
                          color: HxTheme.cream,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('PRO',
                      style: HxTheme.body.copyWith(
                          color: HxTheme.terracottaHi,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                      textAlign: TextAlign.center)),
            ],
          ),
          const Divider(height: 14, color: Colors.white24),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(r.$1,
                        style: HxTheme.body.copyWith(
                            color: HxTheme.cream, fontSize: 13)),
                  ),
                  Expanded(flex: 2, child: _Cell(value: r.$2)),
                  Expanded(flex: 2, child: _Cell(value: r.$3)),
                ],
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: HxTheme.terracotta.withValues(alpha: 0.25),
                  border: Border.all(color: HxTheme.terracottaHi),
                ),
                child: Text('✦ PRO ACTIVE ✦',
                    style: HxTheme.body.copyWith(
                        color: HxTheme.terracottaHi,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final Object value; // bool | String
  const _Cell({required this.value});

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      final v = value as bool;
      return Text(
        v ? '✓' : '—',
        style: HxTheme.body.copyWith(
            color: v
                ? HxTheme.terracottaHi
                : HxTheme.cream.withValues(alpha: 0.4),
            fontSize: 15),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      value as String,
      style: HxTheme.body.copyWith(
          color: HxTheme.terracottaHi,
          fontWeight: FontWeight.w700,
          fontSize: 12),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
class _BuyCard extends StatelessWidget {
  final StoreService store;
  const _BuyCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final set = HxSettings.instance;
    final pro = store.proProduct;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xD84E3A28), Color(0xE6241812)],
        ),
        border: Border.all(color: HxTheme.terracotta, width: 2),
      ),
      child: Column(
        children: [
          Text('Unlock PRO', style: HxTheme.title(20, HxTheme.cream)),
          const SizedBox(height: 8),
          if (set.isPro)
            Text('You already own PRO — thank you!',
                style: HxTheme.body.copyWith(color: HxTheme.cream),
                textAlign: TextAlign.center)
          else if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: HxTheme.body.copyWith(
                  color: HxTheme.cream.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            )
          else if (pro != null) ...[
            Text(
                pro.description.isNotEmpty
                    ? pro.description
                    : 'Unlock everything in Hex, forever.',
                style: HxTheme.body.copyWith(color: HxTheme.cream),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: store.purchaseInProgress,
              builder: (_, busy, _) => ClayButton(
                label: busy ? 'Working…' : 'Get PRO — ${pro.price}',
                glazeColor: HxTheme.terracotta,
                onTap: busy
                    ? () {}
                    : () {
                        HxAudio.instance.click();
                        store.buyPro();
                      },
              ),
            ),
          ],
          ValueListenableBuilder<String?>(
            valueListenable: store.purchaseError,
            builder: (_, err, _) => err == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(err,
                        style: HxTheme.body.copyWith(
                            color: const Color(0xFFE08A8A), fontSize: 13),
                        textAlign: TextAlign.center),
                  ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              HxAudio.instance.click();
              store.restore();
            },
            child: Text('Restore purchases',
                style: HxTheme.body.copyWith(
                    color: HxTheme.terracottaHi,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Consumable tips — pure support, with real store prices.
class _TipsCard extends StatelessWidget {
  final StoreService store;
  const _TipsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final tips = [
      store.coffeeProduct,
      store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xD84E3A28), Color(0xE6241812)],
        ),
        border: Border.all(color: HxTheme.terracotta, width: 2),
      ),
      child: Column(
        children: [
          Text('Tip the Maker', style: HxTheme.title(20, HxTheme.cream)),
          const SizedBox(height: 8),
          Text(
            'Hex is free forever. A small tip keeps new games coming!',
            style: HxTheme.body.copyWith(color: HxTheme.cream),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: HxTheme.body.copyWith(
                  color: HxTheme.cream.withValues(alpha: 0.6), fontSize: 13),
              textAlign: TextAlign.center,
            )
          else if (tips.isEmpty)
            Text('Tips coming soon.',
                style: HxTheme.body.copyWith(
                    color: HxTheme.cream.withValues(alpha: 0.6), fontSize: 13))
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _TipChip(
                    label:
                        '${p.id == StoreService.chocolateId ? '🍫' : '☕'} ${p.price}',
                    onTap: () {
                      HxAudio.instance.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TipChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(
              color: HxTheme.terracotta.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Text(label,
            style: HxTheme.body.copyWith(
                color: HxTheme.cream, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
