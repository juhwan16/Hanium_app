import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_app/core/models/safety_models.dart';
import 'package:hanium_app/features/alerts/event_replay_screen.dart';
import 'package:hanium_app/features/home_map/floor_plan_view.dart';

void main() {
  test('new floor plan boundaries and room centers agree', () {
    expect(RoomResolver.fromPosition(.25, .18), RoomResolver.bathroom);
    expect(RoomResolver.fromPosition(.68, .045), RoomResolver.entrance);
    expect(RoomResolver.fromPosition(.67, .24), RoomResolver.kitchen);
    expect(RoomResolver.fromPosition(.78, .76), RoomResolver.livingSpace);
    expect(RoomResolver.fromPosition(.42, .35), RoomResolver.bathroom);
    expect(RoomResolver.fromPosition(.43, .35), RoomResolver.kitchen);
    expect(RoomResolver.fromPosition(.68, .10), RoomResolver.kitchen);
    expect(RoomResolver.fromPosition(.84, .05), RoomResolver.kitchen);
    expect(RoomResolver.fromPosition(.25, .36), RoomResolver.livingSpace);
    for (final room in RoomResolver.all) {
      final point = RoomResolver.representativePoint(room)!;
      expect(RoomResolver.fromPosition(point.dx, point.dy), room);
    }
    expect(RoomResolver.representativePoint('알 수 없음'), isNull);
  });

  test('live and cached coordinates override previous floor plan names', () {
    expect(RoomResolver.normalize('침실-2', .25, .18), RoomResolver.bathroom);
    expect(RoomResolver.normalize('현관', .78, .76), RoomResolver.livingSpace);
    final cache = SafetySnapshot.initial().toCacheJson();
    cache.addAll({'x': .25, 'y': .18, 'room': '침실-2'});
    expect(SafetySnapshot.fromCacheJson(cache).room, RoomResolver.bathroom);
  });

  test('legacy alerts map to living space without duplicated descriptions', () {
    for (final name in ['거실', '침실', '침실-1', '침실-2']) {
      final alert = AlertEvent.fromJson({
        'room': name,
        'type': 'danger',
        'message': '$name에서 감지했어요.',
      });
      expect(alert.room, RoomResolver.livingSpace);
      expect(alert.message, '${RoomResolver.livingSpace}에서 감지했어요.');
      final fallback = AlertEvent.fromJson({'room': name, 'type': 'danger'});
      expect('생활공간'.allMatches(fallback.message).length, 1);
    }
    final withCoordinates = AlertEvent.fromJson({
      'room': '침실-2',
      'x': .25,
      'y': .18,
      'type': 'danger',
    });
    expect(withCoordinates.room, RoomResolver.bathroom);
    expect(AlertEvent.fromJson({'room': '알 수 없음'}).room, RoomResolver.unknown);
  });

  for (final room in RoomResolver.all) {
    testWidgets(
      '$room replay stays in the matching room and finishes at its center',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: EventReplayScreen(
              alert: AlertEvent.fromStatus(SafetyStatus.danger, room: room),
              baseSnapshot: SafetySnapshot.initial(),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/home_floor_plan_reference.png'),
            tester.element(find.byType(FloorPlanView)),
          ),
        );
        for (var frame = 0; frame < 16; frame++) {
          await tester.pump(const Duration(milliseconds: 70));
          final snapshot = tester
              .widget<FloorPlanView>(find.byType(FloorPlanView))
              .snapshot;
          expect(snapshot.room, room);
          expect(RoomResolver.fromPosition(snapshot.x, snapshot.y), room);
        }
        final snapshot = tester
            .widget<FloorPlanView>(find.byType(FloorPlanView))
            .snapshot;
        final target = RoomResolver.representativePoint(room)!;
        expect(snapshot.x, closeTo(target.dx, .00001));
        expect(snapshot.y, closeTo(target.dy, .00001));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
