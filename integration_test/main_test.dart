import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:cardabase/main.dart';
import 'package:cardabase/pages/home/home_page.dart';
import 'package:faker/faker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

import '../test_helpers/fakers/loyalty_card.dart';
import '../test_helpers/fakers/settings.dart';
import 'test_helpers/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final validEan13 = faker.loyaltyCards.codeEAN13();

  setUpAll(() {
    registerTestDependencies();
  });

  setUp(() async {
    GetIt.I.pushNewScope(scopeName: 'test-scope');
    await initializePlugins();
    await initializeHiveBoxes();
  });

  tearDown(() {
    GetIt.I.popScope();
  });

  group('starting the app', () {
    testWidgets('opens on the cards of the user', (tester) async {
      // ARRANGE
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
      // `main` shows the welcome screen when the version which was last seen is
      // not the one which is running.
      await startApp(
        tester,
        settings: faker.settings.settings(lastSeenAppVersion: null),
      );

      expect(find.textContaining('Welcome'), findsWidgets);

      await tapAndSettle(tester, find.textContaining('Continue'));

      expect(find.text('Cardabase'), findsOneWidget);
      expect(
        storedSettings().lastSeenAppVersion,
        testAppVersion,
        reason: 'the welcome screen should not come back on the next start',
      );
    });

    testWidgets('asks for the password when the app is locked', (tester) async {
      // the third screen `main` can open on: a password which locks the app.
      await startApp(tester, password: 'letmein', lockApp: true);

      expect(find.byType(Homepage), findsNothing);
      expect(find.byType(LockScreen), findsOneWidget);
    });

    testWidgets('a card which was added is still there after a restart',
        (tester) async {
      await startApp(tester);

      await tapAndSettle(tester, find.byIcon(Icons.add_card));
      await enterText(tester, 'Card Name', 'Delhaize');
      await pickBarcodeType(tester, 'EAN-13');
      await enterText(tester, 'Card ID', validEan13);
      await tapAndSettle(tester, find.text('SAVE'));
      expect(find.text('Delhaize'), findsOneWidget);

      // start the app again over the same database, the way a user would come
      // back to it the next day.
      await restartApp(tester);

      expect(find.text('Delhaize'), findsOneWidget);
      expect(storedCardNames(), ['Delhaize']);
    });

    testWidgets('a theme which was chosen is still there after a restart',
        (tester) async {
      await startApp(tester);

      await tapAndSettle(tester, find.byIcon(Icons.settings));
      await scrollTo(tester, find.text('Switch Themes'));
      await tapAndSettle(tester, find.text('Switch Themes'));
      await tapAndSettle(tester, find.byIcon(Icons.arrow_back_ios_new).first);

      await restartApp(tester);

      expect(storedSettings().theme.useDarkMode, isTrue);
      expect(
        Theme.of(tester.element(find.text('Cardabase'))).brightness,
        Brightness.dark,
      );
    });
  });
}
