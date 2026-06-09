import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/app/motion_arcade_app.dart';

void main() {
  testWidgets('shows mode selection on launch', (tester) async {
    await tester.pumpWidget(const MotionArcadeApp());

    expect(find.text('Motion Arcade'), findsOneWidget);
    expect(find.text('Desktop Game'), findsOneWidget);
    expect(find.text('Motion Controller'), findsOneWidget);
  });

  testWidgets('opens desktop mode', (tester) async {
    await tester.pumpWidget(const MotionArcadeApp());

    await tester.tap(find.text('Open room host'));
    await tester.pumpAndSettle();

    expect(find.text('Motion Arcade Host'), findsOneWidget);
    expect(find.text('Create room'), findsOneWidget);
  });

  testWidgets('opens controller mode', (tester) async {
    await tester.pumpWidget(const MotionArcadeApp());

    await tester.tap(find.text('Open controller'));
    await tester.pumpAndSettle();

    expect(find.text('Phone Controller'), findsOneWidget);
    expect(find.text('Server URI'), findsOneWidget);
    expect(find.text('Scan room QR'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Fused Motion'),
      120,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fused Motion'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Sensitivity'),
      120,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sensitivity'), findsOneWidget);
    expect(find.text('Med'), findsOneWidget);
  });
}
