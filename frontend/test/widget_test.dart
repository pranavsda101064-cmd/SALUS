import 'package:flutter_test/flutter_test.dart';
import 'package:salus_frontend/main.dart';

void main() {
  testWidgets('SALUS login renders', (tester) async {
    await tester.pumpWidget(const SalusApp());
    await tester.pumpAndSettle();
    expect(find.text('SALUS'), findsWidgets);
    expect(find.text('Enter command center'), findsOneWidget);
  });
}
