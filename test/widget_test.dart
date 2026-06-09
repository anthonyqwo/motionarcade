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
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('Game Control'), findsOneWidget);

    final controllerList = find.byKey(const ValueKey('controllerHomeList'));

    Future<void> dragUntilVisible(String text, Finder list) async {
      for (var i = 0; i < 8 && find.text(text).evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -320));
        await tester.pumpAndSettle();
      }
    }

    await dragUntilVisible('Score', controllerList);
    expect(find.text('Score'), findsWidgets);

    await dragUntilVisible('Motion Readiness', controllerList);

    expect(find.text('Motion Readiness'), findsOneWidget);
    expect(find.text('Med'), findsOneWidget);

    await dragUntilVisible('Open debug panel', controllerList);

    await tester.tap(find.text('Open debug panel'));
    await tester.pumpAndSettle();

    expect(find.text('Controller Debug'), findsOneWidget);
    expect(find.text('Fused Motion'), findsOneWidget);
    final debugList = find.byKey(const ValueKey('controllerDebugList'));

    await dragUntilVisible('Sensor Debug', debugList);
    expect(find.text('Sensor Debug'), findsOneWidget);

    await dragUntilVisible('Haptic Simulator', debugList);

    expect(find.text('Haptic Simulator'), findsOneWidget);
  });
}
