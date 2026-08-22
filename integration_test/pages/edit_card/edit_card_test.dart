import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../test/test_helpers/app.dart';
import '../../../test/test_helpers/fakers/faker.dart';
import '../../../test/test_helpers/fakers/loyalty_card.dart';
import '../../../test/test_helpers/hive.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final validEan13 = testFaker.loyaltyCards.codeEAN13();

  Future<void> openNewCardForm(WidgetTester tester) async {
    await startApp(tester);
    await tapAndSettle(tester, find.byIcon(Icons.add_card));
  }

  group('filling in a card', () {
    useApp();

    testWidgets('keeps everything which was filled in', (tester) async {
      await openNewCardForm(tester);

      await enterText(tester, 'Card Name', 'Delhaize');
      await pickBarcodeType(tester, 'EAN-13');
      await enterText(tester, 'Card ID', validEan13);
      await enterText(tester, 'Some notes...', 'The one on the corner');
      await tapAndSettle(tester, find.text('SAVE'));

      final stored = storedCards().single;
      expect(stored.name, 'Delhaize');
      expect(stored.barcode.data, validEan13);
      expect(stored.barcode.type, BarcodeType.CodeEAN13);
      expect(stored.notes, 'The one on the corner');
    });

    testWidgets('starts a card without a barcode type', (tester) async {
      await openNewCardForm(tester);

      await enterText(tester, 'Card Name', 'Delhaize');
      await tapAndSettle(tester, find.text('SAVE'));

      expect(
        storedCards().single.barcode.type,
        isNull,
        reason: 'a card gets a type once the user picks one',
      );
    });

    testWidgets('shows the name on the card while it is typed', (tester) async {
      await openNewCardForm(tester);

      await enterText(tester, 'Card Name', 'Delhaize');

      expect(
        find.text('Delhaize'),
        findsWidgets,
        reason: 'the preview should follow the name',
      );
    });

    testWidgets('picks another barcode type', (tester) async {
      await openNewCardForm(tester);

      await enterText(tester, 'Card Name', 'Loyalty');
      await pickBarcodeType(tester, 'QR-Code');
      await enterText(tester, 'Card ID', 'anything goes in a qr code');
      await tapAndSettle(tester, find.text('SAVE'));

      final stored = storedCards().single;
      expect(stored.barcode.type, BarcodeType.QrCode);
      expect(
        stored.barcode.data,
        'anything goes in a qr code',
        reason: 'a qr code is not checked the way a barcode is',
      );
    });
  });

  group('a card which cannot be saved', () {
    useApp();

    testWidgets('says the name is missing', (tester) async {
      await openNewCardForm(tester);

      await enterText(tester, 'Card Name', '');
      await tapAndSettle(tester, find.text('SAVE'));

      expect(snackBarText(tester), 'Card Name cannot be empty!');
      expect(storedCards(), isEmpty);
    });

    testWidgets('says the number is missing once a type is picked',
        (tester) async {
      await openNewCardForm(tester);

      await enterText(tester, 'Card Name', 'Delhaize');
      await pickBarcodeType(tester, 'EAN-13');
      await tapAndSettle(tester, find.text('SAVE'));

      expect(snackBarText(tester), 'Card ID cannot be empty!');
      expect(storedCards(), isEmpty);
    });

    testWidgets('says the number is not a barcode', (tester) async {
      await openNewCardForm(tester);

      await enterText(tester, 'Card Name', 'Delhaize');
      await pickBarcodeType(tester, 'EAN-13');
      // thirteen digits, but the last one does not add up.
      await enterText(tester, 'Card ID', '9780201379625');
      await tapAndSettle(tester, find.text('SAVE'));

      expect(snackBarText(tester), 'Invalid Card ID!');
      expect(storedCards(), isEmpty);
    });

    testWidgets('shows what is wrong on the field itself', (tester) async {
      await openNewCardForm(tester);

      await enterText(tester, 'Card Name', 'Delhaize');
      await pickBarcodeType(tester, 'EAN-13');
      await enterText(tester, 'Card ID', '123');
      await tapAndSettle(tester, find.text('SAVE'));

      expect(find.text('Value must have length 13'), findsOneWidget);
    });
  });

  group('editing a card which exists', () {
    useApp();

    testWidgets('changes it instead of adding another one', (tester) async {
      await startApp(
        tester,
        cards: [
          testFaker.loyaltyCards.simpleCard().copyWith(
                id: 'card-under-test',
                name: 'Delhaize',
                barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
              ),
        ],
      );

      await openCardMenu(tester, 'Delhaize');
      await tapAndSettle(tester, find.text('Edit'));
      await enterText(tester, 'Card Name', 'Delhaize City');
      await tapAndSettle(tester, find.text('SAVE'));

      expect(storedCardNames(), ['Delhaize City']);
      expect(
        storedCards().single.id,
        'card-under-test',
        reason: 'it is the same card',
      );
      expect(find.text('Delhaize City'), findsOneWidget);
    });

    testWidgets('shows the card which is being edited', (tester) async {
      await startApp(
        tester,
        cards: [
          testFaker.loyaltyCards.simpleCard().copyWith(
                name: 'Delhaize',
                notes: 'The one on the corner',
                points: 12,
                usePoints: true,
                barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN8),
              ),
        ],
      );

      await openCardMenu(tester, 'Delhaize');
      await tapAndSettle(tester, find.text('Edit'));

      expect(fieldText(tester, 'Card Name'), 'Delhaize');
      expect(fieldText(tester, 'Card ID'), validEan13);
      expect(find.text('EAN-8'), findsOneWidget);
    });

    testWidgets('leaves the card alone when the form is left', (tester) async {
      await startApp(
        tester,
        cards: [
          testFaker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize'),
        ],
      );

      await openCardMenu(tester, 'Delhaize');
      await tapAndSettle(tester, find.text('Edit'));
      await enterText(tester, 'Card Name', 'Something else');
      await tapAndSettle(tester, find.byIcon(Icons.arrow_back_ios_new).first);

      expect(storedCardNames(), ['Delhaize']);
    });
  });
}
