import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nummo/main.dart';

void main() {
  testWidgets('Nummo app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    expect(find.byType(MainApp), findsOneWidget);
  });
}
