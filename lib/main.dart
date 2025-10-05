
import 'package:device_preview/device_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:reveal_duel/src/app.dart';

void main(List<String> args) {
  if (kDebugMode) {
    runApp(DevicePreview(builder: (context) {
      return RevealDuelApp();
    }));
    return;
  }

  runApp(RevealDuelApp());
}