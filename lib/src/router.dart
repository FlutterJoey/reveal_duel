import 'package:go_router/go_router.dart';
import 'package:reveal_duel/src/game/game_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: "/",
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) {
        return GameScreen();
      },
    ),
  ],
);
