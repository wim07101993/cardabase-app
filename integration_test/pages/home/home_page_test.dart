import 'package:cardabase/feature/cards/card_list_view_options.dart';
import 'package:faker/faker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../test_helpers/fakers/loyalty_card.dart';
import '../../../test_helpers/fakers/settings.dart';
import '../../../test_helpers/hive.dart';
import '../../test_helpers/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final validEan13 = faker.loyaltyCards.codeEAN13();

  group('the card list', () {
    useApp();

    testWidgets('says there is nothing to see when there are no cards',
        (tester) async {
      await startApp(tester);

      expect(find.text('There is nothing to see...'), findsOneWidget);
    });

    testWidgets('shows the cards which are stored', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize'),
          faker.loyaltyCards.simpleCard().copyWith(name: 'Colruyt'),
        ],
      );

      expect(find.text('Delhaize'), findsOneWidget);
      await scrollToCard(tester, 'Colruyt');
      expect(find.text('Colruyt'), findsOneWidget);
      expect(find.text('There is nothing to see...'), findsNothing);
    });
  });

  group('adding a card', () {
    useApp();

    testWidgets('a new card is shown and kept', (tester) async {
      await startApp(tester);

      await tapAndSettle(tester, find.byIcon(Icons.add_card));
      await enterText(tester, 'Card Name', 'Delhaize');
      await pickBarcodeType(tester, 'EAN-13');
      await enterText(tester, 'Card ID', validEan13);
      await tapAndSettle(tester, find.text('SAVE'));

      expect(find.text('Cardabase'), findsOneWidget, reason: 'back on home');
      expect(find.text('Delhaize'), findsOneWidget);
      expect(storedCardNames(), ['Delhaize']);
      expect(
        storedCards().single.barcode.data,
        validEan13,
        reason: 'the number is what makes the barcode',
      );
    });

    testWidgets('a card without a name is not saved', (tester) async {
      await startApp(tester);

      await tapAndSettle(tester, find.byIcon(Icons.add_card));
      await tapAndSettle(tester, find.text('SAVE'));

      expect(storedCards(), isEmpty);
    });
  });

  group('the menu of a card', () {
    useApp();

    testWidgets('duplicates a card, copy and all', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize'),
        ],
      );

      await openCardMenu(tester, 'Delhaize');
      await tapAndSettle(tester, find.text('Duplicate'));

      expect(storedCardNames(), ['Delhaize', 'Delhaize']);
      final cards = storedCards();
      expect(
        cards.first.barcode.data,
        cards.last.barcode.data,
        reason: 'a duplicate holds the same card',
      );
      expect(
        cards.first.id,
        isNot(cards.last.id),
        reason: 'but it is a card of its own',
      );
    });

    testWidgets('moves a card down the order of the user', (tester) async {
      // moving cards around is only offered while the user sorts them
      // themselves, and it is that order which is changed.
      final first = faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize');
      final second = faker.loyaltyCards.simpleCard().copyWith(name: 'Colruyt');
      await startApp(
        tester,
        cards: [first, second],
        settings: faker.settings.settings(
          cardListViewOptions: faker.settings.cardListViewOptions(
            sortingStyle: SortingStyle.custom,
            customOrder: [first.id, second.id],
          ),
        ),
      );

      await openCardMenu(tester, 'Delhaize');
      await tapAndSettle(tester, find.text('Move DOWN'));

      expect(
        storedSettings().cardListViewOptions.customOrder,
        [second.id, first.id],
      );
    });

    testWidgets('moves a card up the order of the user', (tester) async {
      final first = faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize');
      final second = faker.loyaltyCards.simpleCard().copyWith(name: 'Colruyt');
      await startApp(
        tester,
        cards: [first, second],
        settings: faker.settings.settings(
          cardListViewOptions: faker.settings.cardListViewOptions(
            sortingStyle: SortingStyle.custom,
            customOrder: [first.id, second.id],
          ),
        ),
      );

      await scrollToCard(tester, 'Colruyt');
      await openCardMenu(tester, 'Colruyt');
      await tapAndSettle(tester, find.text('Move UP'));

      expect(
        storedSettings().cardListViewOptions.customOrder,
        [second.id, first.id],
      );
    });

    testWidgets('deletes a card, after asking', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize'),
          faker.loyaltyCards.simpleCard().copyWith(name: 'Colruyt'),
        ],
      );

      await openCardMenu(tester, 'Delhaize');
      await tapAndSettle(tester, find.widgetWithText(ListTile, 'DELETE'));

      expect(find.text('Delete Card'), findsOneWidget);
      expect(find.textContaining('Delhaize'), findsWidgets);
      await tapAndSettle(tester, find.widgetWithText(OutlinedButton, 'DELETE'));

      expect(find.text('Delhaize'), findsNothing);
      expect(storedCardNames(), ['Colruyt']);
    });

    testWidgets('opens the card in the edit form', (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize'),
        ],
      );

      await openCardMenu(tester, 'Delhaize');
      await tapAndSettle(tester, find.text('Edit'));

      expect(fieldText(tester, 'Card Name'), 'Delhaize');
    });
  });

  group('the view options', () {
    useApp();

    testWidgets('sort the cards by name', (tester) async {
      final delhaize = faker.loyaltyCards.simpleCard().copyWith(
            name: 'Delhaize',
            lastModifiedAt: DateTime.utc(2024, 1, 1, 12),
          );
      final colruyt = faker.loyaltyCards.simpleCard().copyWith(
            name: 'Colruyt',
            lastModifiedAt: DateTime.utc(2024, 1, 1, 12, 1),
          );
      await startApp(
        tester,
        cards: [delhaize, colruyt],
        settings: faker.settings.settings(
          cardListViewOptions: faker.settings
              .cardListViewOptions(sortingStyle: SortingStyle.latest),
        ),
      );
      expect(
        shownCardIds(tester),
        [colruyt.id, delhaize.id],
        reason: 'the card which changed last comes first',
      );

      await tapAndSettle(tester, find.byIcon(Icons.sort));
      await tapAndSettle(tester, find.byType(DropdownMenu<SortingStyle>));
      await tapAndSettle(tester, find.text('Name 0-Z').last);
      await tapAndSettle(tester, find.text('SELECT'));

      expect(
        storedSettings().cardListViewOptions.sortingStyle,
        SortingStyle.nameAz,
        reason: 'the choice should be saved',
      );
      expect(shownCardIds(tester), [colruyt.id, delhaize.id]);
    });

    testWidgets('remember how many columns the cards are shown in',
        (tester) async {
      await startApp(
        tester,
        cards: [
          faker.loyaltyCards.simpleCard().copyWith(name: 'Delhaize'),
        ],
      );

      await tapAndSettle(tester, find.byIcon(Icons.sort));
      expect(find.text('Columns: 1'), findsOneWidget);
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('SELECT'));

      expect(
        storedSettings().cardListViewOptions.numberOfColumns,
        greaterThan(1),
        reason: 'the choice should be saved',
      );
    });
  });
}
