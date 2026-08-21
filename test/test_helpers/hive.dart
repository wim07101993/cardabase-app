import 'dart:io';

import 'package:cardabase/feature/cards/barcode_type_type_adapter.dart';
import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:cardabase/feature/settings/get_it.dart';
import 'package:cardabase/feature/settings/model.dart';
import 'package:cardabase/hive_registrar.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

/// The boxes the app opens at startup, by the name it opens them under.
const String cardsBoxName = 'cards202603';
const String passwordBoxName = 'password';
const String settingsBoxName = 'settings202603';

Directory? _hiveDirectory;

/// The adapters live in a registry which spans the whole test process, so they
/// can only be registered once however many tests run after this one.
bool _adaptersRegistered = false;

/// Opens the boxes the app expects, in a directory of this test run alone.
///
/// The app reaches for its boxes through get_it and holds on to what it got, so
/// they are opened once for a whole file rather than once per test; [resetHive]
/// is what puts them back to a known state between tests.
Future<void> openHive() async {
  _hiveDirectory =
      await Directory.systemTemp.createTemp('cardabase-test-hive-');
  Hive.init(_hiveDirectory!.path);
  if (!_adaptersRegistered) {
    // `Hive.initFlutter` registers the first two itself, and the app relies on
    // them: a card holds a Color. A test initialises Hive against a directory
    // of its own instead, so it has to register them here.
    Hive
      ..registerAdapter(ColorAdapter())
      ..registerAdapter(TimeOfDayAdapter())
      ..registerAdapter(const BarcodeTypeAdapter())
      ..registerAdapters();
    _adaptersRegistered = true;
  }

  await Hive.openBox<LoyaltyCard>(cardsBoxName);
  await Hive.openBox(passwordBoxName);
  await Hive.openBox<Settings>(settingsBoxName);
}

/// Empties the boxes and fills them with what a test wants to start from.
Future<void> resetHive({
  List<LoyaltyCard> cards = const [],
  Settings? settings,
  String? password,
}) async {
  final box = cardsBox();
  await box.clear();
  await box.putAll({for (final card in cards) card.id: card});

  final passwords = Hive.box(passwordBoxName);
  await passwords.clear();
  if (password != null) {
    await passwords.put('password', password);
  }

  final settings0 = Hive.box<Settings>(settingsBoxName);
  await settings0.clear();
  await settings0.save(settings ?? const Settings.defaultValue());
}

/// Closes the boxes and removes everything [openHive] wrote.
Future<void> closeHive() async {
  await Hive.close();
  final directory = _hiveDirectory;
  _hiveDirectory = null;
  if (directory != null && directory.existsSync()) {
    await directory.delete(recursive: true);
  }
}

/// The box the cards are stored in, which is what the app reads and writes.
LoyaltyCardsBox cardsBox() => Hive.box<LoyaltyCard>(cardsBoxName);

/// The stored cards, in the order the box hands them out.
List<LoyaltyCard> storedCards() => cardsBox().values.toList(growable: false);

/// The names of the stored cards, in the order they are stored in.
List<String> storedCardNames() {
  return storedCards().map((card) => card.name).toList(growable: false);
}

/// The stored card with the given id, or null when it was removed.
LoyaltyCard? storedCard(String id) => cardsBox().get(id);

/// Replaces the stored cards, for a test which wants to start from a specific
/// database without going through the ui.
Future<void> storeCards(List<LoyaltyCard> cards) async {
  final box = cardsBox();
  await box.clear();
  await box.putAll({for (final card in cards) card.id: card});
}

/// [storeCards] from inside a widget test.
///
/// A widget test runs against a clock of its own, and a write to disk started
/// under that clock never finishes; [WidgetTester.runAsync] is what lets it run
/// on the real one.
Future<void> seedCards(WidgetTester tester, List<LoyaltyCard> cards) async {
  await tester.runAsync(() => storeCards(cards));
}

/// The settings box, for a test which wants to read or change settings.
Box<Settings> settingsBox() => Hive.box<Settings>(settingsBoxName);

/// The settings as they are stored, which is what the app reads them as.
Settings storedSettings() => settingsBox().value;

/// Saves settings from inside a widget test, on the real clock.
Future<void> seedSettings(WidgetTester tester, Settings settings) async {
  await tester.runAsync(() => settingsBox().save(settings));
}

/// Opens the boxes for a whole test file and empties them between tests.
void useHive({
  List<LoyaltyCard> Function()? cards,
  Settings Function()? settings,
  String? password,
}) {
  setUpAll(openHive);
  tearDownAll(closeHive);
  setUp(
    () => resetHive(
      cards: cards?.call() ?? const [],
      settings: settings?.call(),
      password: password,
    ),
  );
}
