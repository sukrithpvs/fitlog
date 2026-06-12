// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitlog/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FitLogApp(),
      ),
    );
    await tester.pumpAndSettle();
    
    // Verify app loads
    expect(find.text('Workout'), findsWidgets);
  });
}
