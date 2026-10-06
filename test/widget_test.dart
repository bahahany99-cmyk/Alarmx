import 'package:alarmx/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Native pipeline test screen shows controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('AlarmX - Native Pipeline Test'), findsOneWidget);
    expect(find.text('Schedule test alarm in 10 seconds'), findsOneWidget);
    expect(find.text('Cancel test alarm'), findsOneWidget);
    expect(find.text('Check exact alarm permission'), findsOneWidget);
    expect(find.text('No action yet'), findsOneWidget);
  });
}
