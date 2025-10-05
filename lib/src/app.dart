import 'package:flutter/widgets.dart';
import 'package:reveal_duel/src/router.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;

class RevealDuelApp extends StatelessWidget {
  const RevealDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return shadcn.ShadApp.router(
      routerConfig: router,
      theme: shadcn.ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const shadcn.ShadZincColorScheme.dark(),
        cardTheme: shadcn.ShadCardTheme(
          padding: EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 8,
          ),
        ),
      ),
    );
  }
}
