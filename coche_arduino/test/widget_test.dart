import 'package:flutter_test/flutter_test.dart';
import 'package:coche_arduino/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const CocheArduinoApp());
    expect(find.text('Coche Arduino'), findsOneWidget);
  });
}
