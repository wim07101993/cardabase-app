import 'dart:io';

import 'package:cardabase/feature/cards/edit/widgets/form_fields/barcode_type_selector_button.dart';
import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:cardabase/feature/cards/widgets/card_summary.dart';
import 'package:cardabase/feature/settings/model.dart';
import 'package:cardabase/main.dart';
import 'package:faker/faker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../test_helpers/fakers/settings.dart';
import '../../test_helpers/get_it.dart';
import '../../test_helpers/hive.dart';
import '../../test_helpers/mocks/plugins/clipboard.dart';
import '../../test_helpers/mocks/plugins/haptic_feedback.dart';
import '../../test_helpers/mocks/plugins/path_provider.dart';
import '../../test_helpers/mocks/plugins/permissions.dart';
import '../../test_helpers/mocks/plugins/quick_actions.dart';
import '../../test_helpers/mocks/plugins/receive_sharing_intent.dart';
import '../../test_helpers/mocks/plugins/screen_brightness.dart';

/// The app registers its dependencies -- and with them its hive adapters --
/// which can only happen once however many groups a file holds.
bool _appIsUp = false;

const String testAppVersion = '1.8.0';

/// Brings up everything the app registers for itself.
///
/// The dependencies are the ones `main` registers -- the same boxes, the same
/// migrations, the same services -- with only the platform underneath them
/// answered by a fake: the storage lives in a directory of the tests, and the
/// version comes from a fake package info rather than an installed apk.
///
/// [startApp] then starts the app the way `main` does, so what a test drives is
/// the app rather than an approximation of it.
void useApp({String? password}) {
  setUpAll(() async {
    if (_appIsUp) {
      return;
    }
    _appIsUp = true;

    registerTestDependencies();
  });

  const scopeName = 'test';

  setUp(() async {
    GetIt.I.pushNewScope(scopeName: scopeName);
    // the app is brought up before the test rather than while it runs: a test
    // which drives it starts from an app which is already there.
    await initializePlugins();
    await initializeHiveBoxes();
  });

  tearDown(() async {
    // the scope goes even when emptying the boxes throws: a scope which is
    // left behind fails every test after this one with a complaint about its
    // name rather than about what went wrong here.
    try {
      await resetHive(password: password);
    } finally {
      GetIt.I.dropScope(scopeName);
    }
  });
}

void registerTestDependencies() {
  PackageInfo.setMockInitialValues(
    appName: 'Cardabase',
    packageName: 'com.georgeyt9769.cardabase',
    version: testAppVersion,
    buildNumber: '1',
    buildSignature: '',
  );

  registerDependencies();
  GetIt.I.registerSingleton(
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
  );

  GetIt.I.registerLazySingletonAsync(
    () => Directory.systemTemp.createTemp('cardabase-test-storage-'),
    instanceName: TestGetItInstanceNames.storageDirectory.value,
  );
  GetIt.I
    ..registerMockHapticFeedback()
    ..registerMockQuickActions()
    ..registerMockScreenBrightness()
    ..registerMockSharingIntent()
    ..registerMockPermissions()
    ..registerMockClipboard()
    ..registerMockPathProvider();
}

// initializePlugins gets all mocked plugins from GetIt so that they are
// initialized and wired up.
Future<void> initializePlugins() {
  GetIt.I<MockHapticFeedbackPlatform>();
  GetIt.I<MockQuickActionsPlatform>();
  GetIt.I<MockScreenBrightnessPlatform>();
  GetIt.I<MockSharingIntentPlatform>();
  GetIt.I<MockPermissionsPlatform>();
  GetIt.I<MockClipboardPlatform>();
  return GetIt.I.getAsync<MockPathProviderPlatform>();
}

Future<void> initializeHiveBoxes() async {
  await Future.wait([
    GetIt.I.getAsync<LoyaltyCardsBox>(),
    GetIt.I.getAsync<SettingsBox>(),
    GetIt.I.getAsync<Box>(instanceName: 'passwordBox'),
  ]);
}

/// Starts the app over a database which holds [cards], through the same
/// `run` the app itself starts with: it resolves the boxes, decides which
/// screen to open on and calls `runApp`.
Future<void> startApp(
  WidgetTester tester, {
  List<LoyaltyCard> cards = const [],
  Settings? settings,
  String? password,
  bool lockApp = false,
}) async {
  await tester.runAsync(
    () => resetHive(
      cards: cards,
      settings: settings ?? faker.settings.settings(),
      password: password,
      lockApp: lockApp,
    ),
  );

  // a phone, so the tests see what a user sees: on the default 800x600 test
  // surface the cards are wider and fewer of them fit.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await run();
  await tester.pumpAndSettle();
}

/// Starts the app again over the database it left behind, the way a user comes
/// back to it later.
Future<void> restartApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await run();
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
