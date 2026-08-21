import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../test/test_helpers/app.dart';
import '../../../test/test_helpers/fakers/faker.dart';
import '../../../test/test_helpers/fakers/loyalty_card.dart';
import '../../../test/test_helpers/hive.dart';
import '../../../test/test_helpers/plugins.dart';
import '../../../test/test_helpers/fakers/settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('the settings', () {
    useApp();

    /// Scrolls a setting into view and taps it. The settings have to be open
    /// already.
    Future<void> tapSetting(WidgetTester tester, String setting) async {
      await scrollTo(tester, find.text(setting));
      await tapAndSettle(tester, find.text(setting));
    }

    /// Opens the settings from the card list and taps a setting.
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
          testFaker.loyaltyCards
              .card(name: 'Delhaize', barcodeData: validEan13),
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
        [testFaker.loyaltyCards.card(name: 'Delhaize', barcodeData: validEan13)]
            .serializeToJson(),
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
          testFaker.loyaltyCards
              .card(name: 'Delhaize', barcodeData: validEan13),
          testFaker.loyaltyCards
              .card(name: 'Colruyt', barcodeData: otherValidEan13),
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
        cards: [testFaker.loyaltyCards.card(name: 'Delhaize')],
      );

      await openSetting(tester, 'Tags');
      await tapAndSettle(tester, find.byIcon(Icons.add));
      await tester.enterText(find.byType(TextField).last, 'groceries');
      await tapAndSettle(tester, find.text('ADD'));

      expect(storedSettings().tags, contains('groceries'));
    });

    testWidgets('switching the theme is remembered', (tester) async {
      await startApp(tester, settings: testFaker.settings.settings());
      expect(storedSettings().theme.useDarkMode, isFalse);

      await tapAndSettle(tester, find.byIcon(Icons.settings));
      await tapSetting(tester, 'Switch Themes');

      expect(storedSettings().theme.useDarkMode, isTrue);
    });
  });
}
