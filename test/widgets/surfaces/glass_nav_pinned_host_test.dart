import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_widgets/widgets/surfaces/glass_bar_item.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

GlassBarIconItem _icon(IconData icon, {Object? id}) =>
    GlassBarIconItem(icon: Icon(icon), onTap: () {}, id: id);

void main() {
  group('capsule presence', () {
    double presence(double p, {bool fromEmpty = false, bool toEmpty = true}) =>
        GlassNavPinnedMetrics.capsulePresenceAt(
          fromEmpty: fromEmpty,
          toEmpty: toEmpty,
          progress: p,
        );

    test('a cluster that disappears gels out through the morph window', () {
      expect(presence(0.0), 1.0);
      expect(presence(GlassNavPinnedMetrics.morphStart), 1.0);
      expect(presence(GlassNavPinnedMetrics.morphEnd), closeTo(0.0, 1e-9));
      expect(presence(1.0), 0.0);
    });

    test('a cluster that appears gels in through the morph window', () {
      double v(double p) => presence(p, fromEmpty: true, toEmpty: false);
      expect(v(0.0), 0.0);
      expect(v(GlassNavPinnedMetrics.morphStart), 0.0);
      expect(v(1.0), 1.0);
      // The spring gives an appearing capsule the same bounce past full
      // size that a morphing one gets.
      final peak = List.generate(101, (i) => v(i / 100))
          .reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(1.0));
    });

    test(
      'appearing and disappearing are exact mirrors, so a push and the pop '
      'that undoes it play the same gel',
      () {
        for (var i = 0; i <= 100; i++) {
          final p = i / 100;
          final appearing = presence(p, fromEmpty: true, toEmpty: false);
          // The appearing side keeps its overshoot past 1 (the bounce); the
          // disappearing side is its clamped complement, so it rests cleanly
          // at zero while the other side bounces.
          expect(
            presence(p),
            closeTo((1.0 - appearing).clamp(0.0, 1.0), 1e-9),
            reason: 'the two directions must be complementary at p=$p',
          );
        }
      },
    );

    test('a cluster present on both sides never leaves full presence', () {
      for (var i = 0; i <= 100; i++) {
        expect(
          presence(i / 100, fromEmpty: false, toEmpty: false),
          1.0,
          reason: 'a surviving capsule morphs in place, it does not blink',
        );
      }
    });

    test('nothing to show on either side renders nothing', () {
      for (var i = 0; i <= 100; i++) {
        expect(
          presence(i / 100, fromEmpty: true, toEmpty: true),
          0.0,
        );
      }
    });
  });

  group('configuration swap', () {
    test('switches from the outgoing to the incoming side at the midpoint', () {
      expect(GlassNavPinnedMetrics.showsIncomingAt(0.0), isFalse);
      expect(GlassNavPinnedMetrics.showsIncomingAt(0.49), isFalse);
      expect(GlassNavPinnedMetrics.showsIncomingAt(0.5), isTrue);
      expect(GlassNavPinnedMetrics.showsIncomingAt(1.0), isTrue);
    });

    test('an appearing capsule is already gelling in at the swap point', () {
      // Items appear with their side; the capsule that carries them must be
      // on its way in by the time the configuration swaps, so the arriving
      // icons never render on a capsule that has not started to exist.
      expect(
        GlassNavPinnedMetrics.showsIncomingAt(GlassNavPinnedMetrics.swapAt),
        isTrue,
      );
      expect(
        GlassNavPinnedMetrics.capsulePresenceAt(
          fromEmpty: true,
          toEmpty: false,
          progress: GlassNavPinnedMetrics.swapAt,
        ),
        greaterThan(0.2),
      );
    });
  });

  group('action matching', () {
    test('identifier match wins over position', () {
      final add = _icon(CupertinoIcons.add, id: 'add');
      final more = _icon(CupertinoIcons.ellipsis);
      final search = _icon(CupertinoIcons.search);
      final addAgain = _icon(CupertinoIcons.add, id: 'add');

      // [add, more] -> [search, add]: 'add' moved slots but must stay matched.
      final slots = matchGlassNavActions([add, more], [search, addAgain]);

      final addSlot = slots.singleWhere((s) => s.toItem == addAgain);
      expect(addSlot.fromItem, same(add));

      // 'more' has no counterpart and exits; 'search' enters.
      expect(slots.singleWhere((s) => s.fromItem == more).isExit, isTrue);
      expect(slots.singleWhere((s) => s.toItem == search).isEnter, isTrue);
    });

    test('unidentified items match positionally from the trailing edge', () {
      final a = _icon(CupertinoIcons.add);
      final b = _icon(CupertinoIcons.ellipsis);
      final c = _icon(CupertinoIcons.search);
      final d = _icon(CupertinoIcons.bell);

      // [a, b] -> [c, d]: trailing-edge pairing gives b->d and a->c.
      final slots = matchGlassNavActions([a, b], [c, d]);

      expect(slots.singleWhere((s) => s.toItem == d).fromItem, same(b));
      expect(slots.singleWhere((s) => s.toItem == c).fromItem, same(a));
    });

    test('an item with a different explicit id never matches positionally', () {
      final flagged = _icon(CupertinoIcons.flag, id: 'flag');
      final search = _icon(CupertinoIcons.search, id: 'search');

      final slots = matchGlassNavActions([flagged], [search]);

      // Same trailing slot, but the ids disagree: exit + enter, not a morph.
      expect(slots.singleWhere((s) => s.fromItem == flagged).isExit, isTrue);
      expect(slots.singleWhere((s) => s.toItem == search).isEnter, isTrue);
    });

    test('each outgoing item is consumed at most once', () {
      final add = _icon(CupertinoIcons.add, id: 'add');
      final one = _icon(CupertinoIcons.circle, id: 'add');
      final two = _icon(CupertinoIcons.square, id: 'add');

      final slots = matchGlassNavActions([add], [one, two]);

      final matched = slots.where((s) => s.fromItem == add);
      expect(matched, hasLength(1));
    });

    test('empty sides produce pure enters or pure exits', () {
      final a = _icon(CupertinoIcons.add);

      expect(
        matchGlassNavActions([], [a]).single.isEnter,
        isTrue,
      );
      expect(
        matchGlassNavActions([a], []).single.isExit,
        isTrue,
      );
      expect(matchGlassNavActions([], []), isEmpty);
    });
  });

  group('item tap handlers', () {
    test('an icon item requires a handler, a custom item does not', () {
      var taps = 0;
      final icon = GlassBarItem.icon(
        icon: const Icon(CupertinoIcons.add),
        onTap: () => taps++,
      ) as GlassBarActionItem;
      final passive =
          const GlassBarItem.custom(child: SizedBox()) as GlassBarActionItem;

      icon.onTap();
      expect(taps, 1);

      // Passive custom content still exposes a callable handler, so nothing
      // downstream has to null-check its way around a status readout.
      expect(passive.onTap, returnsNormally);
    });
  });
}
