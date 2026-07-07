import 'package:flutter_test/flutter_test.dart';

import 'package:ash_rise/app.dart';

void main() {
  testWidgets('App boots and shows the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AshRiseApp());
    await tester.pump();

    expect(find.text('Loading'), findsWidgets);
  });
}
