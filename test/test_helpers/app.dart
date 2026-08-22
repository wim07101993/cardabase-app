import 'package:cardabase/feature/cards/edit/widgets/form_fields/barcode_type_selector_button.dart';
import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:cardabase/feature/cards/widgets/card_summary.dart';
import 'package:cardabase/feature/settings/model.dart';
import 'package:cardabase/main.dart';
import 'package:cardabase/pages/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'get_it.dart';
import 'hive.dart';
import 'plugins.dart';
import 'fakers/faker.dart';
import 'fakers/settings.dart';

/// Everything the app needs around it: its boxes, its services and answers for
/// the plugin channels it talks over. Put it at the top of an integration test
/// group.
void useApp({String? password}) {
  useHive(password: password);
  useGetIt();
  usePlugins();
}

/// Starts the app on the screen it would open on, over a database which holds
/// [cards].
///
/// It builds the real [Main] widget, so a test which drives it goes through the
/// same widgets, the same storage and the same settings as the app itself.
Future<void> startApp(
  WidgetTester tester, {
  List<LoyaltyCard> cards = const [],
  Settings? settings,
  String? password,
  Widget? initialScreen,
}) async {
  await tester.runAsync(() async {
    await resetHive(
      cards: cards,
      settings: settings ?? testFaker.settings.settings(),
      password: password,
    );
  });

  // a phone, so the tests see what a user sees: on the default 800x600 test
  // surface the cards are wider and fewer of them fit.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Main(initialScreen: initialScreen ?? const Homepage()),
  );
  await tester.pumpAndSettle();
}

/// Starts the app again over the database it left behind, the way a user comes
/// back to it later.
Future<void> restartApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.pumpWidget(const Main(initialScreen: Homepage()));
  await tester.pumpAndSettle();
}

/// Scrolls until [finder] is on screen, whichever way it has to go.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  final list = scrollable ?? find.byType(Scrollable).first;

  // back to the top first: `scrollUntilVisible` only ever scrolls one way, and
  // a list which is already past what the test is looking for would scroll
  // away from it forever.
  final position = tester.state<ScrollableState>(list).position;
  if (position.pixels != position.minScrollExtent) {
    position.jumpTo(position.minScrollExtent);
    await tester.pumpAndSettle();
  }

  try {
    await tester.scrollUntilVisible(finder, 200, scrollable: list);
  } on StateError {
    // `scrollUntilVisible` gives up with a bare "Bad state: No element", which
    // says nothing about what was being looked for.
    fail('scrolled the whole list without finding $finder');
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the card list until the card with [name] is on screen.
Future<void> scrollToCard(WidgetTester tester, String name) {
  return scrollTo(tester, find.text(name));
}

/// Opens the menu of a card, the one a long press brings up.
Future<void> openCardMenu(WidgetTester tester, String name) async {
  await tester.longPress(find.text(name));
  await tester.pumpAndSettle();
}

/// Taps something in a menu or a dialog and waits for it to close.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The field which carries [label], whether that is its label or its hint.
///
/// The label sits next to the text being edited rather than around it, so the
/// field is found through the [TextField] which holds both.
Finder fieldWithLabel(String label) {
  return find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(TextField)),
    matching: find.byType(EditableText),
  );
}

/// Fills the field which carries [label] and settles the frame.
Future<void> enterText(
  WidgetTester tester,
  String label,
  String text,
) async {
  await tester.enterText(fieldWithLabel(label), text);
  await tester.pumpAndSettle();
}

/// What is in the field which carries [label].
String fieldText(WidgetTester tester, String label) {
  return tester.widget<EditableText>(fieldWithLabel(label)).controller.text;
}

/// Picks a barcode type in the edit form, through the button which shows the
/// one which is set (or 'None' while a new card has none).
Future<void> pickBarcodeType(WidgetTester tester, String label) async {
  await tapAndSettle(tester, find.byType(BarcodeTypeSelectorButton));
  await scrollTo(
    tester,
    find.widgetWithText(ListTile, label),
    scrollable: find.byType(Scrollable).last,
  );
  await tapAndSettle(tester, find.widgetWithText(ListTile, label));
}

/// The ids of the cards on screen, in the order they are shown in.
///
/// The order of the cards is a view concern: the box hands them out in the
/// order they were written, and the view options decide how they are shown.
List<String> shownCardIds(WidgetTester tester) {
  return tester
      .widgetList<CardSummary>(find.byType(CardSummary))
      .map((summary) => summary.cardId)
      .toList(growable: false);
}

/// The text of the snack bar which is on screen, if there is one.
String? snackBarText(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data)
      .whereType<String>();
  return texts.isEmpty ? null : texts.join();
}
