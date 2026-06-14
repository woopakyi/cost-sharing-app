import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cost_sharing_application/main.dart';

void main() {
  testWidgets('cost sharing app starts in guest mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      CostSharingApp(store: AppStore(preferences)..load()),
    );

    expect(find.text('Cost Sharing App'), findsWidgets);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.textContaining('Guest mode'), findsOneWidget);
  });
}
