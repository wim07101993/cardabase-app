import 'package:cardabase/pages/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_helpers/app.dart';
import '../test/test_helpers/fakers/faker.dart';
import '../test/test_helpers/fakers/loyalty_card.dart';
import '../test/test_helpers/hive.dart';
import '../test/test_helpers/fakers/settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('starting the app', () {
    useApp();

    testWidgets('opens on the cards of the user', (tester) async {
      await startApp(
        tester,
        cards: [testFaker.loyaltyCards.card(name: 'Delhaize')],
      );

      expect(find.text('Cardabase'), findsOneWidget);
      expect(find.text('Delhaize'), findsOneWidget);
    });

    testWidgets('shows what is new after an update', (tester) async {
      // `main` shows the welcome screen when the version which was last seen is
      // not the one which is running.
      await startApp(
        tester,
        settings: testFaker.settings.settings(lastSeenAppVersion: null),
        initialScreen: const WelcomeScreen(currentAppVersion: testAppVersion),
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
