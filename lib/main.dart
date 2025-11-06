import 'package:device_preview/device_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:reveal_duel/src/app.dart';
import 'package:reveal_duel/src/game/levels.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences preferences;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  preferences = await SharedPreferences.getInstance();

  await playerProgressionController.load(preferences);

  if (kDebugMode) {
    runApp(
      DevicePreview(
        enabled: false,
        builder: (context) {
          return RevealDuelApp();
        },
      ),
    );
    return;
  }

  runApp(RevealDuelApp());
}
