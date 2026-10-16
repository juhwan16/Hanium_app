import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_app/core/models/safety_models.dart';
import 'package:hanium_app/features/home_map/floor_plan_view.dart';

const _asset = 'assets/images/home_floor_plan_reference.png';
const _previewKey = ValueKey('floor-plan-preview');

Future<void> showPlan(
  WidgetTester tester, {
  required Size size,
  bool compact = false,
  bool shared = true,
  double textScale = 1,
  Offset position = const Offset(0.55, 0.6),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: _previewKey,
              child: FloorPlanView(
                compact: compact,
                snapshot: SafetySnapshot.initial().copyWith(
                  x: position.dx,
                  y: position.dy,
                  locationSharingEnabled: shared,
                  movementPath: const [
                    Offset(0.55, 0.69),
                    Offset(0.55, 0.66),
                    Offset(0.55, 0.63),
                    Offset(0.55, 0.6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(_asset),
      tester.element(find.byType(FloorPlanView)),
    );
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'reference plan renders with entrance, window and movement overlay',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showPlan(tester, size: const Size(390, 820));
      expect(tester.takeException(), isNull);
      expect(find.byType(MiniPersonMarker), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        const AssetImage(_asset),
      );
      await expectLater(
        find.byKey(_previewKey),
        matchesGoldenFile('goldens/home_floor_plan.png'),
      );
    },
  );

  testWidgets(
    'compact and landscape maps keep corner markers inside the view',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(240, 600), const Size(740, 320)]) {
        for (final corner in [Offset.zero, const Offset(1, 1)]) {
          await showPlan(
            tester,
            size: size,
            compact: true,
            textScale: 2,
            position: corner,
          );
          final map = tester.getRect(find.byType(FloorPlanView));
          final marker = tester.getRect(find.byType(MiniPersonMarker));
          expect(map.contains(marker.topLeft), isTrue);
          expect(map.contains(marker.bottomRight), isTrue);
          expect(tester.takeException(), isNull);
        }
      }
      await showPlan(
        tester,
        size: const Size(240, 600),
        shared: false,
        textScale: 2,
      );
      expect(find.byType(MiniPersonMarker), findsNothing);
      expect(find.text('피보호자가 위치 공유를 꺼두었어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
