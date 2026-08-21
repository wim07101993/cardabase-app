import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The channel the haptics of the app talk over.
const MethodChannel hapticsChannel = MethodChannel('haptic_feedback');

/// The channel the home-screen shortcuts are set over.
const MethodChannel quickActionsChannel =
    MethodChannel('plugins.flutter.io/quick_actions');

/// The channel the screen brightness is read and set over.
const MethodChannel screenBrightnessChannel =
    MethodChannel('github.com/aaassseee/screen_brightness');

/// The channels the app listens on for what another app shared with it.
const MethodChannel sharingIntentChannel =
    MethodChannel('receive_sharing_intent/messages');
const MethodChannel sharingIntentEventChannel =
    MethodChannel('receive_sharing_intent/events-media');

/// The channel permissions are asked for over.
const MethodChannel permissionsChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');

/// The channel the clipboard is behind.
const MethodChannel platformChannel = SystemChannels.platform;

/// Answers the plugin channels the app uses, the way a device would.
///
/// A headless test has no plugins behind its channels: every call throws a
/// [MissingPluginException], and a vibration which throws would fail a test
/// about something else entirely. Call it from `setUp`; the bindings clear the
/// handlers again between tests.
void setUpPlugins({bool canVibrate = true, bool grantPermissions = true}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(hapticsChannel, (call) async {
    return switch (call.method) {
      'canVibrate' => canVibrate,
      _ => null,
    };
  });

  messenger.setMockMethodCallHandler(quickActionsChannel, (call) async => null);

  // nothing was shared with the app, and nothing will be while a test runs.
  messenger.setMockMethodCallHandler(
    sharingIntentChannel,
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    sharingIntentEventChannel,
    (call) async => null,
  );

  messenger.setMockMethodCallHandler(screenBrightnessChannel, (call) async {
    return switch (call.method) {
      'getScreenBrightness' ||
      'getSystemScreenBrightness' ||
      'getApplicationScreenBrightness' =>
        0.5,
      _ => null,
    };
  });

  // `PermissionStatus.granted` is the second value of the enum the plugin
  // answers with, `denied` the first.
  const granted = 1;
  const denied = 0;
  messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
    return switch (call.method) {
      'checkPermissionStatus' => grantPermissions ? granted : denied,
      'requestPermissions' => {
          call.arguments is List
              ? (call.arguments as List).first
              : call.arguments: grantPermissions ? granted : denied,
        },
      _ => null,
    };
  });

  _clipboard = null;
  messenger.setMockMethodCallHandler(platformChannel, (call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        _clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      case 'Clipboard.getData':
        return {'text': _clipboard};
      default:
        return null;
    }
  });
}

String? _clipboard;

/// What was last copied to the clipboard, as far as the fake platform saw.
String? get clipboardText => _clipboard;

/// Registers [setUpPlugins] around every test of a group.
void usePlugins({bool canVibrate = true, bool grantPermissions = true}) {
  setUp(
    () => setUpPlugins(
      canVibrate: canVibrate,
      grantPermissions: grantPermissions,
    ),
  );
}
