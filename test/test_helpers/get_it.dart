import 'package:cardabase/feature/cards/loyalty_card.dart';
import 'package:cardabase/feature/settings/model.dart';
import 'package:cardabase/util/vibration_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'hive.dart';
import 'fakers/settings.dart';

/// Registers what the app resolves from [GetIt] at runtime, against the boxes
/// [openHive] opened.
///
/// The registrations are the same ones `main` makes, minus the asynchronous
/// initialisation and the migrations: the boxes are already open, and already
/// hold what the test put in them.
void setUpGetIt({String appVersion = testAppVersion}) {
  GetIt.I
    ..registerSingleton<HiveInterface>(Hive)
    ..registerSingleton<LoyaltyCardsBox>(cardsBox())
    ..registerSingleton<Box>(
      Hive.box(passwordBoxName),
      instanceName: 'passwordBox',
    )
    ..registerSingleton<SettingsBox>(settingsBox())
    ..registerSingleton<VibrationProvider>(
      VibrationProvider(settingsBox: GetIt.I<SettingsBox>()),
    )
    ..registerSingleton<PackageInfo>(
      PackageInfo(
        appName: 'Cardabase',
        packageName: 'com.georgeyt9769.cardabase',
        version: appVersion,
        buildNumber: '1',
      ),
    );
}

/// Empties [GetIt] again, so the next test registers into a clean one.
Future<void> tearDownGetIt() => GetIt.I.reset();

/// Registers [setUpGetIt] and [tearDownGetIt] around every test of a group.
void useGetIt({String appVersion = testAppVersion}) {
  setUp(() => setUpGetIt(appVersion: appVersion));
  tearDown(tearDownGetIt);
}
