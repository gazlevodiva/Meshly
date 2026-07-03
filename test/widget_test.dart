import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/main.dart';

void main() {
  testWidgets('App launches', (tester) async {
    await tester.pumpWidget(const MeshlyApp(onboardingDone: true));
    expect(find.byType(MeshlyApp), findsOneWidget);
  });
}
