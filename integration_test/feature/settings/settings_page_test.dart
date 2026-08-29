import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:cardabase/feature/settings/get_it.dart';
import 'package:cardabase/feature/settings/model.dart';
import 'package:cardabase/main.dart';
import 'package:cardabase/pages/home/home_page.dart';
import 'package:faker/faker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

import '../../../test_helpers/fakers/loyalty_card.dart';
import '../../../test_helpers/fakers/settings.dart';
import '../../../test_helpers/mocks/plugins/clipboard.dart';
import '../../app_harness.dart';

/// What the app last copied to the clipboard, as the fake platform saw it.
String? get clipboardText => GetIt.I<MockClipboardPlatform>().clipboardText;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final validEan13 = faker.loyaltyCards.codeEAN13();
  final otherValidEan13 = faker.loyaltyCards.codeEAN13();

  useApp();

  group('the settings', () {
    Future<void> tapSetting(WidgetTester tester, String setting) async {
      await scrollTo(tester, find.text(setting));
      await tapAndSettle(tester, find.text(setting));
    }

    Future<void> openSetting(WidgetTester tester, String setting) async {
      await tapAndSettle(tester, find.byIcon(Icons.settings));
      await tapSetting(tester, setting);
    }

    /// Opens the backup half of the import/export page, which is the tab it
    /// opens on.
    Future<void> openExport(WidgetTester tester) async {
      await openSetting(tester, 'Backup/Restore');
    }

    /// Opens the restore half of the same page.
    Future<void> openImport(WidgetTester tester) async {
      await openSetting(tester, 'Backup/Restore');
      await tapAndSettle(tester, find.byIcon(Icons.download));
    }

    /// Leaves a settings page which is a screen of its own, back to the list
    /// of settings.
    Future<void> goBack(WidgetTester tester) async {
      await tapAndSettle(tester, find.byIcon(Icons.arrow_back_ios_new).first);
    }

    testWidgets('open from the cards and close again', (tester) async {
      // ARRANGE
      usePhoneView(tester);

      // ACT
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byIcon(Icons.settings));

      // ASSERT
      expect(find.text('Settings'), findsOneWidget);

      await tapAndSettle(tester, find.byIcon(Icons.arrow_back_ios_new).first);
      expect(find.text('Cardabase'), findsOneWidget);
    });

    testWidgets('exporting copies the cards to the clipboard', (tester) async {
      // ARRANGE
      usePhoneView(tester);
      final loyaltyCardsBox = await GetIt.I.getAsync<LoyaltyCardsBox>();
      await loyaltyCardsBox.put(
        'delhaize',
        faker.loyaltyCards.simpleCard().copyWith(
              id: 'delhaize',
              name: 'Delhaize',
              barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
            ),
      );

      // ACT
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();
      await openExport(tester);
      await tapAndSettle(tester, find.text('CLIPBOARD'));

      // ASSERT
      expect(clipboardText, contains('"name":"Delhaize"'));
      expect(clipboardText, contains(validEan13));
    });

    testWidgets('importing adds the cards of a backup', (tester) async {
      // ARRANGE
      usePhoneView(tester);
      final backup = [
        faker.loyaltyCards.simpleCard().copyWith(
              name: 'Delhaize',
              barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
            ),
      ].serializeToJson();

      // ACT
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();
      await openImport(tester);
      await tester.enterText(find.byType(TextField).last, backup);
      await tapAndSettle(tester, find.text('IMPORT FROM TEXT'));

      // ASSERT
      final loyaltyCardsBox = await GetIt.I.getAsync<LoyaltyCardsBox>();
      expect(loyaltyCardsBox.values.map((card) => card.name), ['Delhaize']);
      expect(
        find.text('Delhaize'),
        findsOneWidget,
        reason: 'the cards should be shown after the import',
      );
    });

    testWidgets('an export can be imported again', (tester) async {
      // ARRANGE
      usePhoneView(tester);
      final loyaltyCardsBox = await GetIt.I.getAsync<LoyaltyCardsBox>();
      await loyaltyCardsBox.putAll({
        'delhaize': faker.loyaltyCards.simpleCard().copyWith(
              id: 'delhaize',
              name: 'Delhaize',
              barcode: Barcode(data: validEan13, type: BarcodeType.CodeEAN13),
            ),
        'colruyt': faker.loyaltyCards.simpleCard().copyWith(
              id: 'colruyt',
              name: 'Colruyt',
              barcode:
                  Barcode(data: otherValidEan13, type: BarcodeType.CodeEAN13),
            ),
      });
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();

      // ACT back it up,
      await openExport(tester);
      await tapAndSettle(tester, find.text('CLIPBOARD'));
      final backup = clipboardText!;
      await goBack(tester);

      // lose the cards -- clearing them closes the settings again,
      await tapSetting(tester, 'Delete Cardabase');
      await tapAndSettle(tester, find.text('DELETE'));
      expect(loyaltyCardsBox.values, isEmpty);
      expect(find.text('There is nothing to see...'), findsOneWidget);

      // and put them back.
      await openImport(tester);
      await tester.enterText(find.byType(TextField).last, backup);
      await tapAndSettle(tester, find.text('IMPORT FROM TEXT'));

      // ASSERT
      expect(
        loyaltyCardsBox.values.map((card) => card.name),
        containsAll(['Delhaize', 'Colruyt']),
      );
    });

    testWidgets('adding a tag makes it available on a card', (tester) async {
      // ARRANGE
      usePhoneView(tester);
      final loyaltyCardsBox = await GetIt.I.getAsync<LoyaltyCardsBox>();
      await loyaltyCardsBox.put(
        'delhaize',
        faker.loyaltyCards
            .simpleCard()
            .copyWith(id: 'delhaize', name: 'Delhaize'),
      );

      // ACT
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();
      await openSetting(tester, 'Tags');
      await tapAndSettle(tester, find.byIcon(Icons.add));
      await tester.enterText(find.byType(TextField).last, 'groceries');
      await tapAndSettle(tester, find.text('ADD'));

      // ASSERT
      final settingsBox = await GetIt.I.getAsync<SettingsBox>();
      expect(settingsBox.value.tags, contains('groceries'));
    });

    testWidgets('switching the theme is remembered', (tester) async {
      // ARRANGE
      usePhoneView(tester);
      final settingsBox = await GetIt.I.getAsync<SettingsBox>();
      await settingsBox.save(faker.settings.settings());
      expect(settingsBox.value.theme.useDarkMode, isFalse);

      // ACT
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byIcon(Icons.settings));
      await tapSetting(tester, 'Switch Themes');

      // ASSERT
      expect(settingsBox.value.theme.useDarkMode, isTrue);
    });
  });
}
