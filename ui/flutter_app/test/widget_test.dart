import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';

void main() {
  testWidgets('App loads home title', (WidgetTester tester) async {
    await tester.pumpWidget(const CassavaDetectorApp());

    expect(find.text('Cassava Detector'), findsOneWidget);
  });
}
