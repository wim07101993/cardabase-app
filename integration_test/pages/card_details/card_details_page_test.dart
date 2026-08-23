import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart' as widget;
import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:faker/faker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../test_helpers/fakers/loyalty_card.dart';
import '../../test_helpers/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final validEan13 = faker.loyaltyCards.codeEAN13();

  group('opening a card', () {
    useApp();

    testWidgets('shows the barcode of the card', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(
                name: 'Delhaize',
                points: 12,
                usePoints: true,
                barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
              ),
        ],
      );

      await tapAndSettle(tester, find.text('Delhaize'));

      expect(find.text('Delhaize'), findsWidgets);
      expect(find.text('12 points'), findsOneWidget);
      final barcode = tester
          .widget<widget.BarcodeWidget>(find.byType(widget.BarcodeWidget));
      expect(utf8.decode(barcode.data), validEan13);
      expect(barcode.barcode.name, widget.Barcode.ean13().name);
    });

    testWidgets('shows the notes of the card', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards
              .simpleCard()
              .copyWith(name: 'Delhaize', notes: 'The one on the corner'),
        ],
      );

      await tapAndSettle(tester, find.text('Delhaize'));

      expect(find.text('The one on the corner'), findsOneWidget);
    });

    testWidgets('goes back to the cards', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize'),
        ],
      );

      await tapAndSettle(tester, find.text('Delhaize'));
      await tapAndSettle(tester, find.byIcon(Icons.arrow_back_ios_new).first);

      expect(find.text('Cardabase'), findsOneWidget);
    });

    testWidgets('shares the card as a code', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(
                name: 'Delhaize',
                barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
              ),
        ],
      );

      await tapAndSettle(tester, find.text('Delhaize'));
      await tapAndSettle(tester, find.byIcon(Icons.qr_code_2));

      // the card is shared as the json another phone can scan.
      final codes = tester
          .widgetList<widget.BarcodeWidget>(find.byType(widget.BarcodeWidget))
          .map((barcode) => utf8.decode(barcode.data))
          .where((data) => data.startsWith('{'));
      expect(codes, isNotEmpty, reason: 'the card should be shown as a code');
      expect(codes.first, contains('Delhaize'));
      expect(codes.first, contains(validEan13));
    });
  });
}
