import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:cardabase/feature/settings/get_it.dart';
import 'package:cardabase/feature/settings/model.dart';
import 'package:cardabase/main.dart';
import 'package:cardabase/pages/home/home_page.dart';
import 'package:cardabase/pages/lock_screen.dart';
import 'package:cardabase/pages/welcome_screen.dart';
import 'package:faker/faker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:integration_test/integration_test.dart';

import '../test_helpers/fakers/loyalty_card.dart';
import '../test_helpers/fakers/settings.dart';
import 'app_harness.dart';

void main() => testMain();

void testMain() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final validEan13 = faker.loyaltyCards.codeEAN13();

  useApp();

  group('starting the app', () {
    testWidgets('opens on the cards of the user', (tester) async {
      // ARRANGE
      usePhoneView(tester);
      final loyaltyCardsBox = await GetIt.I.getAsync<LoyaltyCardsBox>();
      await loyaltyCardsBox.put(
        'shop-1',
        faker.loyaltyCards.simpleCard().copyWith(id: 'shop-1', name: 'Shop 1'),
      );

      // ACT
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();

      expect(find.text('Shop 1'), findsOneWidget);
    });

    testWidgets('shows what is new after an update', (tester) async {
      // ARRANGE the welcome screen is what the app opens on when the version
      // which was last seen is not the one which is running.
      usePhoneView(tester);
      final settingsBox = await GetIt.I.getAsync<SettingsBox>();
      await settingsBox.save(faker.settings.settings(lastSeenAppVersion: null));

      // ACT
      await tester.pumpWidget(
        Main(initialScreen: WelcomeScreen(currentAppVersion: testAppVersion)),
      );
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.textContaining('Welcome'), findsWidgets);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Cardabase'), findsOneWidget);
      expect(
        settingsBox.value.lastSeenAppVersion,
        testAppVersion,
        reason: 'the welcome screen should not come back on the next start',
      );
    });

    testWidgets('asks for the password when the app is locked', (tester) async {
      // ARRANGE a user who put a password in front of the app.
      usePhoneView(tester);
      final passwordBox =
          await GetIt.I.getAsync<Box>(instanceName: 'passwordBox');
      await passwordBox.putAll({'PW': 'letmein', 'lock_app': true});
      final loyaltyCardsBox = await GetIt.I.getAsync<LoyaltyCardsBox>();
      await loyaltyCardsBox.put(
        'shop-1',
        faker.loyaltyCards.simpleCard().copyWith(id: 'shop-1', name: 'Shop 1'),
      );

      // ACT
      await tester.pumpWidget(Main(initialScreen: LockScreen()));
      await tester.pumpAndSettle();

      // ASSERT the cards stay behind the lock screen until the password is in.
      expect(find.byType(Homepage), findsNothing);
      expect(find.text('Shop 1'), findsNothing);
      expect(find.text('Enter your password to continue'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'letmein');
      await tester.pumpAndSettle();
      await tester.tap(find.text('UNLOCK'));
      await tester.pumpAndSettle();

      expect(find.byType(Homepage), findsOneWidget);
      expect(find.text('Shop 1'), findsOneWidget);
    });

    testWidgets('a card which was added is still there after a restart',
        (tester) async {
      // ARRANGE
      usePhoneView(tester);
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();

      // ACT
      await tester.tap(find.byIcon(Icons.add_card));
      await tester.pumpAndSettle();
      await tester.enterText(fieldWithLabel('Card Name'), 'Delhaize');
      await tester.pumpAndSettle();
      await pickBarcodeType(tester, 'EAN-13');
      await tester.enterText(fieldWithLabel('Card ID'), validEan13);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Delhaize'), findsOneWidget);

      // the app is built again over the same database, the way a user comes
      // back to it the next day.
      await restart(tester, Homepage());

      // ASSERT
      expect(find.text('Delhaize'), findsOneWidget);
      final loyaltyCardsBox = await GetIt.I.getAsync<LoyaltyCardsBox>();
      expect(
        loyaltyCardsBox.values.map((card) => card.name),
        ['Delhaize'],
      );
    });

    testWidgets('a theme which was chosen is still there after a restart',
        (tester) async {
      // ARRANGE
      usePhoneView(tester);
      await tester.pumpWidget(Main(initialScreen: Homepage()));
      await tester.pumpAndSettle();

      // ACT
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Switch Themes'));
      await tester.tap(find.text('Switch Themes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new).first);
      await tester.pumpAndSettle();

      await restart(tester, Homepage());

      // ASSERT
      final settingsBox = await GetIt.I.getAsync<SettingsBox>();
      expect(settingsBox.value.theme.useDarkMode, isTrue);
      expect(
        Theme.of(tester.element(find.text('Cardabase'))).brightness,
        Brightness.dark,
      );
    });
  });
}
