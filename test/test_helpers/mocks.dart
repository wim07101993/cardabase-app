import 'package:flutter/services.dart';

class MockClipboard {
  String? text;

  Future<Object?> handleChannelMethodCall(MethodCall call) {
    switch (call.method) {
      case 'Clipboard.setData':
        text = (call.arguments as Map)['text'] as String?;
        return Future.value();
      case 'Clipboard.getData':
        return Future.value({'text': text});
      default:
        return Future.value();
    }
  }
}
