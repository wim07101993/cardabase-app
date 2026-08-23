import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:faker/faker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

import '../../../test_helpers/fakers/loyalty_card.dart';
import '../../../test_helpers/fakers/settings.dart';
import '../../../test_helpers/hive.dart';
import '../../../test_helpers/mocks/plugins/clipboard.dart';
import '../../test_helpers/app.dart';

/// What the app last copied to the clipboard, as the fake platform saw it.
String? get clipboardText => GetIt.I<MockClipboardPlatform>().clipboardText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final validEan13 = faker.loyaltyCards.codeEAN13();
  final otherValidEan13 = faker.loyaltyCards.codeEAN13();

  group('the settings', () {
    useApp();

    Future<void> tapSetting(WidgetTester tester, String setting) async {
      await scrollTo(tester, find.text(setting));
      await tapAndSettle(tester, find.text(setting));
    }

    Future<void> openSetting(WidgetTester tester, String setting) async {
      await tapAndSettle(tester, find.byIcon(Icons.settings));
      await tapSetting(tester, setting);
    }

    testWidgets('open from the cards and close again', (tester) async {
      await startApp(tester);

      await tapAndSettle(tester, find.byIcon(Icons.settings));
      expect(find.text('Settings'), findsOneWidget);

      await tapAndSettle(tester, find.byIcon(Icons.arrow_back_ios_new).first);
      expect(find.text('Cardabase'), findsOneWidget);
    });

    testWidgets('exporting copies the cards to the clipboard', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(
                name: 'Delhaize',
                barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
              ),
        ],
      );

      await openSetting(tester, 'Export Cardabase');
      await tapAndSettle(tester, find.text('CLIPBOARD'));

      expect(clipboardText, contains('"name":"Delhaize"'));
      expect(clipboardText, contains(validEan13));
    });

    testWidgets('importing adds the cards of a backup', (tester) async {
      await startApp(tester);

      await openSetting(tester, 'Import Cardabase');
      await tester.enterText(
        find.byType(TextField).last,
        [
          faker.loyaltyCards.simpleCard().copyWith(
                name: 'Delhaize',
                barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
              ),
        ].serializeToJson(),
      );
      await tapAndSettle(tester, find.text('Import'));

      expect(storedCardNames(), ['Delhaize']);
      expect(
        find.text('Delhaize'),
        findsOneWidget,
        reason: 'the cards should be shown after the import',
      );
    });

    testWidgets('an export can be imported again', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(
                name: 'Delhaize',
                barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
              ),
          faker.loyaltyCards.simpleCard().copyWith(
                name: 'Colruyt',
                barcode:
                    Barcode(data: otherValidEan13, type: BarcodeType.CodeEAN13),
              ),
        ],
      );

      // back it up,
      await openSetting(tester, 'Export Cardabase');
      await tapAndSettle(tester, find.text('CLIPBOARD'));
      final backup = clipboardText!;

      // lose the cards -- clearing them closes the settings again,
      await tapSetting(tester, 'Delete Cardabase');
      await tapAndSettle(tester, find.text('DELETE'));
      expect(storedCards(), isEmpty);
      expect(find.text('There is nothing to see...'), findsOneWidget);

      // and put them back.
      await openSetting(tester, 'Import Cardabase');
      await tester.enterText(find.byType(TextField).last, backup);
      await tapAndSettle(tester, find.text('Import'));

      expect(storedCardNames(), containsAll(['Delhaize', 'Colruyt']));
    });

    testWidgets('adding a tag makes it available on a card', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize'),
        ],
      );

      await openSetting(tester, 'Tags');
      await tapAndSettle(tester, find.byIcon(Icons.add));
      await tester.enterText(find.byType(TextField).last, 'groceries');
      await tapAndSettle(tester, find.text('ADD'));

      expect(storedSettings().tags, contains('groceries'));
    });

    testWidgets('switching the theme is remembered', (tester) async {
      await startApp(tester, settings: faker.settings.settings());
      expect(storedSettings().theme.useDarkMode, isFalse);

      await tapAndSettle(tester, find.byIcon(Icons.settings));
      await tapSetting(tester, 'Switch Themes');

      expect(storedSettings().theme.useDarkMode, isTrue);
    });
  });
}
