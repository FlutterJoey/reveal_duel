import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:reveal_duel/src/game/game_controller.dart';
import 'package:reveal_duel/src/game/game_screen.dart';
import 'package:reveal_duel/src/game/levels.dart';
import 'package:reveal_duel/src/game/models.dart';
import 'package:reveal_duel/src/settings/player.dart';
import 'package:reveal_duel/src/util/uuid.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onPlayGame, super.key});

  final void Function() onPlayGame;

  @override
  Widget build(BuildContext context) {
    var divider = Divider(height: 20, indent: 20, endIndent: 20);

    Future<void> onTapLevel(int levelId) async {
      var level = GameLevel.getById(levelId);
      gameNotifier.setupLevel(level, playerNotifier.activePlayer);
      onPlayGame();
    }

    return Scaffold(
      body: Align(
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(Size(500, double.infinity)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 76, child: TitleBar()),
              divider,
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: LevelPath(onTapLevel: onTapLevel)),
                  ],
                ),
              ),
              divider,
              SizedBox(height: 140, child: BottomBar(onPlayGame: onPlayGame)),
            ],
          ),
        ),
      ),
    );
  }
}

class LevelPath extends HookWidget {
  const LevelPath({required this.onTapLevel, super.key});

  final void Function(int levelId) onTapLevel;

  static final _randomSeed = "RevealDuel".codeUnits.fold<int>(
    0,
    (a, b) => a + b,
  );

  static var i = 0;

  @override
  Widget build(BuildContext context) {
    var levels = GameLevel.getAllLevels();
    var levelPositions = useMemoized(() {
      var random = Random(_randomSeed);
      return levels.indexed.map((entry) {
        var (index, level) = entry;
        var cyclePosition = index % 6;
        var cycle = index ~/ 6;
        var randomXOffset = random.nextDouble() * 0.1 - 0.05;
        var randomYOffset = random.nextDouble() * 0.1 - 0.05;
        var xPositionInCycle =
            switch (cyclePosition) {
              0 => 0.25,
              1 => 0.55,
              2 => 0.7,
              3 => 0.50,
              4 => 0.2,
              6 || _ => 0.1,
            } +
            randomXOffset;
        var yPositionInCycle =
            switch (cyclePosition) {
              0 || 1 => 0.5,
              2 => 1,
              3 || 4 => 1.5,
              5 || _ => 2,
            } +
            randomYOffset;

        return Point<double>(xPositionInCycle, yPositionInCycle + cycle * 2);
      }).toList();
    }, [levels.length]);

    var maxLevel = useListenableSelector(
      playerProgressionController,
      () => playerProgressionController.getLevel(),
    );

    const heightPerRow = 180;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: SizedBox(
            height: levelPositions.last.y * heightPerRow + 280,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: LevelPathPainter(
                      visiblePositions: maxLevel,
                      positions: levelPositions,
                      heightPerRow: 180,
                    ),
                  ),
                ),
                for (var (index, level) in levels.indexed) ...[
                  Positioned(
                    key: ValueKey(level),
                    left: levelPositions[index].x * constraints.maxWidth,
                    bottom: levelPositions[index].y * heightPerRow,
                    child: HookBuilder(
                      builder: (context) {
                        var (levelId, _) = level;

                        bool isLevelUnlocked = levelId <= maxLevel;
                        useEffect(() {
                          if (maxLevel != levelId) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Scrollable.ensureVisible(
                              context,
                              curve: Curves.easeInOut,
                              duration: Duration(seconds: 3),
                              alignment: 0.66,
                            );
                          });
                          return null;
                        }, [maxLevel]);
                        return TappableGameCard(
                          onTapCard: isLevelUnlocked
                              ? (_) => onTapLevel(level.$1)
                              : null,
                          gameCard: GameCard(
                            value: level.$1,
                            revealed: isLevelUnlocked,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class LevelPathPainter extends CustomPainter {
  final List<Point<double>> positions;
  final int visiblePositions;
  final double heightPerRow;

  LevelPathPainter({
    required this.heightPerRow,
    required this.positions,
    required this.visiblePositions,
    super.repaint,
  });

  Offset _offsetFromPosition(Point<double> position, Size size) {
    return Offset(
      size.width * position.x + 50,
      size.height - position.y * heightPerRow - 30,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) return;

    var lowerPaint = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;

    var upperPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var path = Path();
    var bottomPath = Path();

    var startOffset = _offsetFromPosition(positions.first, size);
    path.moveTo(startOffset.dx, startOffset.dy);
    bottomPath.moveTo(startOffset.dx, startOffset.dy);

    for (var i = 1; i < positions.length; i++) {
      var targetPosition = positions[i];
      var previousPosition = positions[i - 1];
      var target = _offsetFromPosition(targetPosition, size);

      if (previousPosition.y == targetPosition.y) {
        path.lineTo(target.dx, target.dy);
        if (i < visiblePositions) {
          bottomPath.lineTo(target.dx, target.dy);
        }
        continue;
      }

      var previous = _offsetFromPosition(previousPosition, size);

      double x;
      double y;
      (x, y) = switch (targetPosition) {
        Point<double>(x: < 0.4) when target.dx < previous.dx => (
          target.dx,
          previous.dy,
        ),
        Point<double>(x: > 0.4) when target.dx > previous.dx => (
          target.dx,
          previous.dy,
        ),
        _ => (previous.dx, target.dy),
      };

      path.quadraticBezierTo(x, y, target.dx, target.dy);
      if (i < visiblePositions) {
        bottomPath.quadraticBezierTo(x, y, target.dx, target.dy);
      }
    }

    canvas.drawPath(bottomPath, lowerPaint);
    canvas.drawPath(path, upperPaint);
  }

  @override
  bool shouldRepaint(covariant LevelPathPainter oldDelegate) {
    return oldDelegate.positions != positions;
  }
}

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = shadcn.ShadTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppLogo(),
        SizedBox(width: 16),
        Text("Reveal Duel", style: theme.textTheme.h1),
      ],
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    var appLogo = SizedBox(
      width: 120,
      height: 60,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: SizedBox(
              height: 40,
              child: FittedBox(
                child: TappableGameCard(
                  gameCard: GameCard(value: -2, revealed: true),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: SizedBox(
              height: 40,
              child: FittedBox(
                child: TappableGameCard(gameCard: GameCard(value: -2)),
              ),
            ),
          ),
          Align(
            child: Icon(
              Icons.sync,
              size: 50,
              shadows: [Shadow(color: Colors.black, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );

    return appLogo;
  }
}

class LevelDescriptor extends StatelessWidget {
  const LevelDescriptor({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Text("Content")],
    );
  }
}

class BottomBar extends StatelessWidget {
  const BottomBar({required this.onPlayGame, super.key});

  final void Function() onPlayGame;

  Future<void> playVsPlayer(BuildContext context) async {
    var opponentName = await showDialog<String>(
      context: context,
      builder: (context) {
        String? name;
        return shadcn.ShadDialog(
          title: Text("Name of opponent"),
          actions: [
            shadcn.ShadButton(
              onPressed: () => Navigator.of(context).pop(name),
              child: Text("Submit"),
            ),
          ],
          child: shadcn.ShadInput(
            onChanged: (value) {
              name = value;
            },
          ),
        );
      },
    );

    if (opponentName == null) return;
    var opponentPlayer = Player(name: opponentName, id: uuid.v4());
    gameNotifier.setupPvPGame(playerNotifier.activePlayer, opponentPlayer);
    onPlayGame();
  }

  void playVsCpu() {
    gameNotifier.setupCPUGame(playerNotifier.activePlayer);
    onPlayGame();
  }

  void playNextLevel() {
    var level = GameLevel.getById(playerProgressionController.getLevel());
    gameNotifier.setupLevel(level, playerNotifier.activePlayer);
    onPlayGame();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: QuickActionButton(
            onPressed: () => playVsPlayer(context),
            text: "VS player",
            color: Colors.green,
            icon: Icons.person,
          ),
        ),
        Expanded(
          child: QuickActionButton(
            onPressed: playNextLevel,
            text: "Next Level",
            color: Colors.red,
            icon: Icons.games_rounded,
          ),
        ),
        Expanded(
          child: QuickActionButton(
            onPressed: playVsCpu,
            text: "VS Computer",
            color: Colors.blue,
            icon: Icons.assistant,
          ),
        ),
      ],
    );
  }
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    required this.onPressed,
    required this.text,
    required this.color,
    required this.icon,
    super.key,
  });

  final void Function() onPressed;
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: null,
              padding: EdgeInsets.zero,
              icon: Icon(icon, color: color),
              iconSize: 40,
            ),
            SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}
