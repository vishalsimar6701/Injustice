import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injustice/main.dart';

void main() {
  testWidgets('App starts with disclaimer and can navigate to feed', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const InjusticeApp());

    // Verify that disclaimer is shown.
    expect(find.text('INJUSTICE: LEGAL NOTICE'), findsOneWidget);
    
    // Checkbox is initially false
    final checkbox = find.byType(Checkbox);
    expect(tester.widget<Checkbox>(checkbox).value, false);

    // Tap the checkbox
    await tester.tap(checkbox);
    await tester.pump();

    // Tap "ENTER PLATFORM"
    await tester.tap(find.text('ENTER PLATFORM'));
    
    // Use pump instead of pumpAndSettle because of periodic timer in FeedScreen
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Should now be on FeedScreen
    expect(find.text('ACCOUNTABILITY FEED'), findsOneWidget);
  });
}
