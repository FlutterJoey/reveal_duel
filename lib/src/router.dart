import 'package:go_router/go_router.dart';
import 'package:reveal_duel/src/game/game_screen.dart';
import 'package:reveal_duel/src/home/home_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: "/home",
  redirect: (() {
    bool isInitialLaunch = true;
    return (context, state) {
      if (isInitialLaunch) {
        isInitialLaunch = false;
        return "/home";
      }
      return null;
    };
  })(),
  routes: [
    GoRoute(
      path: "/game",
      builder: (context, state) {
        return GameScreen(
          onExit: () {
            context.go("/home");
          },
        );
      },
    ),
    GoRoute(
      path: "/home",
      builder: (context, state) {
        return HomeScreen(
          onPlayGame: () {
            context.go("/game");
          },
        );
      },
    ),
  ],
);
