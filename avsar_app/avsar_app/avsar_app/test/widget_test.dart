import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avsar_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Uygulamayı başlat
    await tester.pumpWidget(const MyApp());

    // Async işlemler tamamlanana kadar bekle
    await tester.pumpAndSettle();

    // İlk ekran yüklendi mi kontrol et
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // '+' butonuna tıkla ve değişimi test et
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
