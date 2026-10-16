import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/models/safety_models.dart';
import '../../shared/ui/app_ui.dart';

const _viewAspectRatio = 0.52;
const _referenceImageSize = Size(1024, 1536);
// Keep the entrance door and window; omit the poster heading and footer.
const _referenceCrop = Rect.fromLTWH(204, 145, 616, 1255);
// Normalized location coordinates cover the inside of the exterior walls.
const _referenceInterior = Rect.fromLTRB(258, 243, 766, 1284);
const _floorPlanAsset = 'assets/images/home_floor_plan_reference.png';

class FloorPlanView extends StatelessWidget {
  const FloorPlanView({
    required this.snapshot,
    this.compact = false,
    this.showPath,
    super.key,
  });

  final SafetySnapshot snapshot;
  final bool compact;
  final bool? showPath;

  @override
  Widget build(BuildContext context) {
    final shouldShowPath =
        snapshot.locationSharingEnabled &&
        (showPath ?? snapshot.settingBool('showPath', true));

    return LayoutBuilder(
      builder: (context, viewport) {
        final screen = MediaQuery.sizeOf(context);
        final width = viewport.hasBoundedWidth
            ? viewport.maxWidth
            : screen.width;
        final preferredHeight = math.min(
          width / _viewAspectRatio,
          screen.height * (compact ? 0.42 : 0.56),
        );
        return SizedBox(
          width: width,
          height: viewport.constrainHeight(preferredHeight),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final imageRect = _imageRectFor(size, compact: compact);
              final planRect = _planRectFor(imageRect);
              final personPoint = _personPoint(snapshot);
              final personPosition = _toPlanOffset(planRect, personPoint);
              final markerSize = math.min(
                44.0,
                math.max(0.0, math.min(size.width, size.height) - 16),
              );
              final markerInset = math.min(
                8.0,
                math.min(size.width, size.height) / 2,
              );

              return ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 24 : 30),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.white),
                    ),
                    Positioned.fromRect(
                      rect: imageRect,
                      child: const _ReferenceFloorPlan(),
                    ),
                    if (shouldShowPath)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MovementOverlayPainter(
                            planRect: planRect,
                            path: _movementPath(snapshot),
                            color: _trailColor(snapshot.status),
                          ),
                        ),
                      ),
                    if (snapshot.locationSharingEnabled)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        left: (personPosition.dx - markerSize / 2)
                            .clamp(
                              markerInset,
                              math.max(
                                markerInset,
                                size.width - markerSize - markerInset,
                              ),
                            )
                            .toDouble(),
                        top: (personPosition.dy - markerSize / 2)
                            .clamp(
                              markerInset,
                              math.max(
                                markerInset,
                                size.height - markerSize - markerInset,
                              ),
                            )
                            .toDouble(),
                        child: SizedBox(
                          width: markerSize,
                          height: markerSize,
                          child: FittedBox(
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: MiniPersonMarker(snapshot: snapshot),
                            ),
                          ),
                        ),
                      ),
                    if (!snapshot.locationSharingEnabled)
                      const _LocationHiddenOverlay(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

Rect _imageRectFor(Size size, {required bool compact}) {
  final padding = compact ? 6.0 : 10.0;
  final availableWidth = math.max(0.0, size.width - padding * 2);
  final availableHeight = math.max(0.0, size.height - padding * 2);
  final scale = math.min(
    availableWidth / _referenceCrop.width,
    availableHeight / _referenceCrop.height,
  );
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: _referenceCrop.width * scale,
    height: _referenceCrop.height * scale,
  );
}

Rect _planRectFor(Rect imageRect) {
  final scale = imageRect.width / _referenceCrop.width;
  return Rect.fromLTWH(
    imageRect.left + (_referenceInterior.left - _referenceCrop.left) * scale,
    imageRect.top + (_referenceInterior.top - _referenceCrop.top) * scale,
    _referenceInterior.width * scale,
    _referenceInterior.height * scale,
  );
}

class _ReferenceFloorPlan extends StatelessWidget {
  const _ReferenceFloorPlan();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '우리집 평면도. 위쪽 왼편 욕실, 위쪽 오른편 현관과 주방, '
          '중문 아래 침실과 생활공간. 아래쪽 창문.',
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / _referenceCrop.width;
          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -_referenceCrop.left * scale,
                  top: -_referenceCrop.top * scale,
                  width: _referenceImageSize.width * scale,
                  height: _referenceImageSize.height * scale,
                  child: Image.asset(
                    _floorPlanAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Offset _toPlanOffset(Rect planRect, Offset point) {
  final x = point.dx.clamp(0.0, 1.0).toDouble();
  final y = point.dy.clamp(0.0, 1.0).toDouble();
  return Offset(
    planRect.left + planRect.width * x,
    planRect.top + planRect.height * y,
  );
}

Offset _personPoint(SafetySnapshot snapshot) {
  return Offset(
    snapshot.x.clamp(0.0, 1.0).toDouble(),
    snapshot.y.clamp(0.0, 1.0).toDouble(),
  );
}

Color _trailColor(SafetyStatus status) {
  return switch (status) {
    SafetyStatus.normal => const Color(0xFF6178FF),
    SafetyStatus.out => AppColors.warning,
    SafetyStatus.still => const Color(0xFF7C86FF),
    SafetyStatus.danger => AppColors.danger,
  };
}

List<Offset> _movementPath(SafetySnapshot snapshot) {
  final cleaned = snapshot.movementPath
      .map(
        (point) => Offset(
          point.dx.clamp(0.0, 1.0).toDouble(),
          point.dy.clamp(0.0, 1.0).toDouble(),
        ),
      )
      .toList();

  if (cleaned.length >= 2) {
    const visiblePointCount = 4;
    if (cleaned.length <= visiblePointCount) return cleaned;
    return cleaned.sublist(cleaned.length - visiblePointCount);
  }

  final current = _personPoint(snapshot);
  return [
    Offset(
      (current.dx - 0.16).clamp(0.0, 1.0).toDouble(),
      (current.dy - 0.11).clamp(0.0, 1.0).toDouble(),
    ),
    Offset(
      (current.dx - 0.08).clamp(0.0, 1.0).toDouble(),
      (current.dy - 0.04).clamp(0.0, 1.0).toDouble(),
    ),
    current,
  ];
}

class _MovementOverlayPainter extends CustomPainter {
  const _MovementOverlayPainter({
    required this.planRect,
    required this.path,
    required this.color,
  });

  final Rect planRect;
  final List<Offset> path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    final rawPoints = path
        .map((point) => _toPlanOffset(planRect, point))
        .toList();
    final points = _smoothPoints(rawPoints);
    _drawHumanAfterImages(canvas, points);
  }

  List<Offset> _smoothPoints(List<Offset> source) {
    if (source.length < 2) return source;
    if (source.length == 2) {
      return _interpolateSegment(source.first, source.last, 10);
    }

    final result = <Offset>[];
    for (var i = 0; i < source.length - 1; i++) {
      final p0 = source[(i - 1).clamp(0, source.length - 1).toInt()];
      final p1 = source[i];
      final p2 = source[i + 1];
      final p3 = source[(i + 2).clamp(0, source.length - 1).toInt()];

      for (var step = 0; step < 6; step++) {
        result.add(_catmullRom(p0, p1, p2, p3, step / 6));
      }
    }
    result.add(source.last);
    return result;
  }

  List<Offset> _interpolateSegment(Offset start, Offset end, int count) {
    return List.generate(count + 1, (index) {
      final t = index / count;
      return Offset.lerp(start, end, t)!;
    });
  }

  Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    return Offset(
      0.5 *
          ((2 * p1.dx) +
              (-p0.dx + p2.dx) * t +
              (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
              (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
      0.5 *
          ((2 * p1.dy) +
              (-p0.dy + p2.dy) * t +
              (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
              (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
    );
  }

  void _drawHumanAfterImages(Canvas canvas, List<Offset> points) {
    if (points.isEmpty) return;

    final ghostCount = math.min(4, points.length);
    for (var ghostIndex = 0; ghostIndex < ghostCount; ghostIndex++) {
      final t = ghostCount == 1 ? 1.0 : ghostIndex / (ghostCount - 1);
      final sourceIndex = ((points.length - 1) * t)
          .round()
          .clamp(0, points.length - 1)
          .toInt();
      final point = points[sourceIndex];
      final isLatest = ghostIndex == ghostCount - 1;
      final alpha = isLatest ? 0.42 : 0.12 + ghostIndex * 0.075;
      final scale = isLatest ? 0.92 : 0.66 + ghostIndex * 0.08;
      final previous = points[math.max(0, sourceIndex - 1)];
      final next = points[math.min(points.length - 1, sourceIndex + 1)];
      final angle = _movementAngle(previous, next);

      _drawHumanGhost(
        canvas,
        point,
        angle: angle,
        alpha: alpha,
        scale: scale,
        latest: isLatest,
      );
    }
  }

  double _movementAngle(Offset previous, Offset next) {
    final vector = next - previous;
    if (vector.distance < 0.01) return 0;
    return math.atan2(vector.dy, vector.dx) + math.pi / 2;
  }

  void _drawHumanGhost(
    Canvas canvas,
    Offset center, {
    required double angle,
    required double alpha,
    required double scale,
    required bool latest,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    final softShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: latest ? 0.08 : 0.045)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(0, 3), latest ? 19 : 15, softShadowPaint);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.52)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, latest ? 24 : 19, glowPaint);

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = latest ? 2.2 : 1.6
      ..color = color.withValues(alpha: alpha * 0.42);
    canvas.drawCircle(Offset.zero, latest ? 22 : 18, haloPaint);

    final bodyPaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = latest ? 4.5 : 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final headPaint = Paint()..color = color.withValues(alpha: alpha);

    canvas.drawCircle(const Offset(0, -13), latest ? 4.6 : 3.8, headPaint);
    canvas.drawLine(const Offset(0, -7), const Offset(0, 8), bodyPaint);
    canvas.drawLine(const Offset(0, -2), const Offset(-8, 4), bodyPaint);
    canvas.drawLine(const Offset(0, -2), const Offset(8, 4), bodyPaint);
    canvas.drawLine(const Offset(0, 8), const Offset(-7, 18), bodyPaint);
    canvas.drawLine(const Offset(0, 8), const Offset(7, 18), bodyPaint);

    if (latest) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = color.withValues(alpha: 0.28);
      canvas.drawCircle(Offset.zero, 24, ringPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MovementOverlayPainter oldDelegate) {
    return oldDelegate.planRect != planRect ||
        oldDelegate.path != path ||
        oldDelegate.color != color;
  }
}

class MiniPersonMarker extends StatelessWidget {
  const MiniPersonMarker({required this.snapshot, super.key});

  final SafetySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final isDanger = snapshot.status == SafetyStatus.danger;
    final color = statusColor(snapshot.status);

    return Center(
      child: AnimatedRotation(
        turns: isDanger ? 0.25 : 0,
        duration: const Duration(milliseconds: 140),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            painter: _PersonPainter(color: color, danger: isDanger),
          ),
        ),
      ),
    );
  }
}

class _PersonPainter extends CustomPainter {
  const _PersonPainter({required this.color, required this.danger});

  final Color color;
  final bool danger;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      Offset(center.dx, size.height * 0.25),
      5,
      Paint()..color = color,
    );
    canvas.drawLine(
      Offset(center.dx, size.height * 0.36),
      Offset(center.dx, size.height * 0.62),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, size.height * 0.46),
      Offset(size.width * 0.28, size.height * 0.56),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, size.height * 0.46),
      Offset(size.width * 0.72, size.height * 0.56),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, size.height * 0.62),
      Offset(size.width * 0.34, size.height * 0.82),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, size.height * 0.62),
      Offset(size.width * 0.66, size.height * 0.82),
      paint,
    );

    if (danger) {
      canvas.drawCircle(
        center,
        size.width * 0.54,
        Paint()..color = color.withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PersonPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.danger != danger;
  }
}

class _LocationHiddenOverlay extends StatelessWidget {
  const _LocationHiddenOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        alignment: Alignment.center,
        color: Colors.white.withValues(alpha: 0.58),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, color: AppColors.muted),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  '피보호자가 위치 공유를 꺼두었어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
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
