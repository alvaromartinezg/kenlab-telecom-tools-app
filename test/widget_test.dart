import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenlab_telecom_tools/main.dart';

void main() {
  testWidgets('shows the welcome screen and responds to Test', (tester) async {
    await tester.pumpWidget(const KenLabApp());

    expect(find.text('KenLab Telecom Tools'), findsOneWidget);
    expect(find.text('Welcome to KenLab'), findsOneWidget);
    expect(find.text('Button works!'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Test'));
    await tester.pump();

    expect(find.text('Button works!'), findsOneWidget);
  });
}
