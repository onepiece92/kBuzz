import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/widgets/app_toast.dart';

void main() {
  // A minimal host that exposes a context below MaterialApp's root overlay,
  // which is where AppToast inserts.
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            ctx = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    return ctx;
  }

  // Drain the auto-dismiss timer + slide-out so no timer outlives the test.
  // Tests pass an explicit 1s hold, so 2s clears it (fake time — instant).
  Future<void> flush(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  group('AppToast.fire', () {
    testWidgets('itemises every fire in the batch (no "+N more" collapsing)',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Burger', stationName: 'Grill', qty: 2),
          FireToastItem(dishName: 'Momo', stationName: 'Steam'),
          FireToastItem(dishName: 'Fries', stationName: 'Fryer', qty: 3),
        ],
        duration: const Duration(seconds: 1),
      );
      await tester.pump(); // insert
      await tester.pump(const Duration(milliseconds: 300)); // slide-in

      // Header carries the batch count.
      expect(find.text('FIRE NOW · 3'), findsOneWidget);
      // Every station + dish is rendered.
      expect(find.text('2× Burger'), findsOneWidget);
      expect(find.text('Grill'), findsOneWidget);
      expect(find.text('Momo'), findsOneWidget);
      expect(find.text('Steam'), findsOneWidget);
      expect(find.text('3× Fries'), findsOneWidget);
      expect(find.text('Fryer'), findsOneWidget);

      await flush(tester);
    });

    testWidgets('a single fire uses the plain header (no count)',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Burger', stationName: 'Grill', qty: 2),
        ],
        duration: const Duration(seconds: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('FIRE NOW'), findsOneWidget);
      expect(find.text('2× Burger'), findsOneWidget);

      await flush(tester);
    });

    testWidgets('the corner ✕ dismisses the toast immediately',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Burger', stationName: 'Grill'),
        ],
        duration: const Duration(seconds: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle(); // slide-out + remove

      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('Burger'), findsNothing);

      // The original auto-dismiss timer is still queued; firing it must be a
      // harmless no-op now that the toast is gone (re-entry guard / !mounted).
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('dismiss() animates the active toast out (e.g. run paused)',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Burger', stationName: 'Grill'),
        ],
        duration: const Duration(seconds: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Burger'), findsOneWidget);

      AppToast.dismiss();
      await tester.pumpAndSettle(); // slide-out + remove
      expect(find.text('Burger'), findsNothing);

      // The original auto-dismiss timer is now a harmless no-op.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('dismiss() is a no-op when nothing is showing',
        (WidgetTester tester) async {
      await pumpHost(tester);
      AppToast.dismiss(); // must not throw
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('retime() reschedules the active fire toast from now',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Burger', stationName: 'Grill'),
        ],
        duration: const Duration(seconds: 60),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('FIRE NOW'), findsOneWidget);

      // Shorten to 5s while it's on screen.
      AppToast.retime(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('FIRE NOW'), findsOneWidget); // still up at +4s

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('FIRE NOW'), findsNothing); // gone by ~5s, not 60s
    });

    testWidgets('retime() is a no-op when nothing is showing',
        (WidgetTester tester) async {
      await pumpHost(tester);
      AppToast.retime(const Duration(seconds: 5)); // must not throw
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('retime() leaves a non-fire toast on its own schedule',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.success(ctx, 'Saved', duration: const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved'), findsOneWidget);

      // A fire-time change must NOT extend a success toast (it isn't retimeable).
      AppToast.retime(const Duration(minutes: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4)); // past its own 3s hold
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets(
        'each fire stacks as its own toast, each with its own expire timer',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Burger', stationName: 'Grill'),
        ],
        duration: const Duration(seconds: 10),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // slide-in
      expect(find.text('Burger'), findsOneWidget);

      // 6s in, a second fire arrives — it STACKS as its own toast (not a
      // content-swap of the first), so both are on screen at once.
      await tester.pump(const Duration(seconds: 6));
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Fries', stationName: 'Fryer'),
        ],
        duration: const Duration(seconds: 10),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Burger'), findsOneWidget);
      expect(find.text('Fries'), findsOneWidget);
      expect(find.text('FIRE NOW'), findsNWidgets(2));

      // Each runs its OWN 10s timer: the first (older) expires while the second
      // — added 6s later — is still up.
      await tester.pump(const Duration(seconds: 5)); // ~11s first / ~5s second
      await tester.pumpAndSettle();
      expect(find.text('Burger'), findsNothing); // first gone on its own timer
      expect(find.text('Fries'), findsOneWidget); // second still counting down

      await tester.pump(const Duration(seconds: 6)); // drain the second
      await tester.pumpAndSettle();
      expect(find.text('Fries'), findsNothing);
    });

    testWidgets('a message toast renders an optional note as a second line',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.success(
        ctx,
        'Saved',
        note: 'Synced to the cloud',
        duration: const Duration(seconds: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Synced to the cloud'), findsOneWidget);

      await flush(tester);
    });

    testWidgets('a fire toast renders an optional note under the header',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Burger', stationName: 'Grill'),
        ],
        note: 'Plate together',
        duration: const Duration(seconds: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('FIRE NOW'), findsOneWidget);
      expect(find.text('Plate together'), findsOneWidget);

      await flush(tester);
    });

    testWidgets('an empty batch shows nothing', (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(ctx, items: const <FireToastItem>[]);
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.textContaining('FIRE NOW'), findsNothing);
    });
  });

  group('AppToast stacking', () {
    testWidgets('a second toast stacks below the first, not replacing it',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.success(ctx, 'First', duration: const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First'), findsOneWidget);

      AppToast.error(ctx, 'Second', duration: const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Both visible at once — the old one wasn't dismissed.
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      // The newer toast sits BELOW the older one.
      expect(
        tester.getTopLeft(find.text('Second')).dy,
        greaterThan(tester.getTopLeft(find.text('First')).dy),
      );

      AppToast.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('a fire alert and a normal toast can show at the same time',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      AppToast.fire(
        ctx,
        items: const <FireToastItem>[
          FireToastItem(dishName: 'Burger', stationName: 'Grill'),
        ],
        duration: const Duration(seconds: 5),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      AppToast.success(ctx, 'Saved', duration: const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('FIRE NOW'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      AppToast.dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets('the stack is capped — the oldest normal toast drops',
        (WidgetTester tester) async {
      final BuildContext ctx = await pumpHost(tester);
      for (int i = 0; i < 6; i++) {
        AppToast.show(ctx, 'T$i', duration: const Duration(seconds: 10));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // _maxVisible = 4: the two oldest were dropped, the newest survive.
      expect(find.text('T0'), findsNothing);
      expect(find.text('T1'), findsNothing);
      expect(find.text('T5'), findsOneWidget);

      AppToast.dismiss();
      await tester.pumpAndSettle();
    });
  });
}
