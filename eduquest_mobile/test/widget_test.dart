import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduquest_mobile/main.dart';

void main() {
  testWidgets('App starts rendering without crashing', (WidgetTester tester) async {
    // Membangun aplikasi kita dan memicu frame render pertama.
    await tester.pumpWidget(const EduQuestApp());

    // Menunggu animasi atau transisi halaman selesai (masuk ke RegisterPage)
    await tester.pumpAndSettle();

    // Memastikan bahwa kerangka dasar aplikasi (MaterialApp) berhasil dimuat
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Nanti kalau kamu mau test tulisan di RegisterPage, bisa pakai ini:
    // expect(find.text('Register'), findsWidgets); 
  });
}