import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_app/core/services/safety_repository.dart';
import 'package:hanium_app/core/state/safety_controller.dart';
import 'package:hanium_app/features/home_map/floor_plan_view.dart';
import 'package:hanium_app/features/home_map/home_map_screen.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 1.34, 2.0]) {
      testWidgets('map fits $size at text scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = SafetyController(SafetyRepository());
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: HomeMapScreen(controller: controller),
              bottomNavigationBar: const SizedBox(height: 80),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/home_floor_plan_reference.png'),
            tester.element(find.byType(HomeMapScreen)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final map = tester.getRect(find.byType(FloorPlanView));
        if (size.height > size.width && scale <= 1.34) {
          expect(map.bottom, lessThanOrEqualTo(size.height - 80));
        }
        if (size == const Size(390, 844) && scale == 1.0) {
          await expectLater(
            find.byType(Scaffold).first,
            matchesGoldenFile('goldens/home_map_responsive.png'),
          );
        }
        await tester.tapAt(map.topLeft + const Offset(70, 40));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(tester.takeException(), isNull);
        final expanded = tester.getRect(find.byType(FloorPlanView).last);
        expect(expanded.top, greaterThanOrEqualTo(0));
        expect(expanded.bottom, lessThanOrEqualTo(size.height));
        expect(expanded.right, lessThanOrEqualTo(size.width));
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
