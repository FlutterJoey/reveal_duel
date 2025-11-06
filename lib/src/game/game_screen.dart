import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:reveal_duel/src/game/game_controller.dart';
import 'package:reveal_duel/src/game/levels.dart';
import 'package:reveal_duel/src/game/models.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;
import 'package:shared_preferences/shared_preferences.dart';

extension on Player {
  Color get color => Colors.primaries[id.hashCode % Colors.primaries.length];
}

class GameScreen extends HookWidget {
  const GameScreen({required this.onExit, super.key});

  final void Function() onExit;

  void exitGame() {
    gameNotifier.reset();
    onExit();
  }

  @override
  Widget build(BuildContext context) {
    var hasGame = useListenableSelector(gameNotifier, () => true);

    if (!hasGame) {
      return SafeArea(
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              shadcn.ShadButton(
                onPressed: () {
                  exitGame();
                },
                child: Text("Return to home screen"),
              ),
            ],
          ),
        ),
      );
    }

    return ActiveGameLayout(onExit: exitGame);
  }
}

class ActiveGameLayout extends HookWidget {
  const ActiveGameLayout({super.key, required this.onExit});

  final void Function() onExit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(Size(500, double.infinity)),
          child: Column(
            children: [
              GameStateDialogs(onExit: onExit),
              GameHeader(),
              SizedBox(height: 20),
              Divider(),
              SizedBox(height: 20),
              Expanded(child: Board()),
              SizedBox(height: 100, child: LevelDisplay(onExitGame: onExit)),
            ],
          ),
        ),
      ),
    );
  }
}

class GameStateDialogs extends HookWidget {
  const GameStateDialogs({required this.onExit, super.key});

  final void Function() onExit;

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      GameState? previousState;
      Future<void> listen() async {
        if (!gameNotifier.gameAvailable) {
          previousState = null;
          return;
        }
        var currentState = gameNotifier.game.state;
        if (previousState == currentState) return;
        previousState = currentState;

        switch (currentState) {
          // gamestates that are not relevant to show dialogs for
          case GameState.running:
          case GameState.setup:
            break;
          case GameState.roundFinished:
            showDialog(
              context: context,
              builder: (context) {
                return const EndOfRoundDialog();
              },
            );

          case GameState.finished:
            var result = await showDialog(
              context: context,
              builder: (context) {
                return const EndOfGameDialog();
              },
            );

            if (result == true) {
              var level = GameLevel.getById(gameNotifier.currentLevel!);
              var player = gameNotifier.game.ownPlayer.player;
              gameNotifier.reset();
              gameNotifier.setupLevel(level, player);
            } else {
              onExit();
            }
        }
      }

      gameNotifier.addListener(listen);

      return () {
        gameNotifier.removeListener(listen);
      };
    }, []);

    return const SizedBox.shrink();
  }
}

class EndOfRoundDialog extends StatelessWidget {
  const EndOfRoundDialog({super.key});

  Widget getPlayerStandings(GamePlayer player, TextStyle style) {
    return Text(
      "${player.player.name}: ${player.points} / ${player.pointTarget}",
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = shadcn.ShadTheme.of(context).textTheme;
    var style = textTheme.list;
    return shadcn.ShadDialog(
      title: Text("Round finished"),
      description: Text("Round ${gameNotifier.game.round} finished"),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Text("Standings", style: textTheme.h3),
                getPlayerStandings(gameNotifier.game.ownPlayer, style),
                getPlayerStandings(gameNotifier.game.opponent, style),
              ],
            ),
          ),
          Expanded(
            child: shadcn.ShadButton(
              onPressed: () {
                gameNotifier.updateGame((game) => game.startNextRound());
                Navigator.of(context).pop();
              },
              child: Text("Start next round"),
            ),
          ),
        ],
      ),
    );
  }
}

class EndOfGameDialog extends StatelessWidget {
  const EndOfGameDialog({super.key});

  @override
  Widget build(BuildContext context) {
    var levelId = gameNotifier.currentLevel;
    if (levelId != null) {
      return EndOfLevelDialog(levelId: levelId);
    }

    var winner = gameNotifier.game.getWinner();
    return shadcn.ShadDialog(
      title: Text("Game Finished"),
      actions: [
        shadcn.ShadButton(
          onPressed: () {
            gameNotifier.updateGame((game) {
              return Game.fresh(
                game.ownPlayer.player,
                game.opponent.player,
                game.options,
              );
            });
          },
          child: Text("Reset"),
        ),
        shadcn.ShadButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text("Back to home"),
        ),
      ],
      child: Text("${winner.player.name} wins!"),
    );
  }
}

class EndOfLevelDialog extends HookWidget {
  const EndOfLevelDialog({super.key, required this.levelId});

  final int levelId;

  @override
  Widget build(BuildContext context) {
    var gamePlayer = gameNotifier.game.ownPlayer;
    var completedLevel =
        gameNotifier.game.getWinner().player.id == gamePlayer.player.id;
    var statistics = useMemoized(
      () => LevelStatistic(
        bestPlayerScore: gamePlayer.pointTarget - gamePlayer.points,
        bestTime: DateTime.now().difference(gameNotifier.start!).abs(),
      ),
    );

    if (!completedLevel) {
      return shadcn.ShadDialog(
        title: Text("Level failed!"),
        description: Text(
          "It seems this level got the better of you, better luck next time!",
        ),
        actions: [
          shadcn.ShadButton(
            child: Text("Retry"),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          shadcn.ShadButton(
            child: Text("Exit"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }

    return shadcn.ShadDialog(
      title: Text("Level $levelId complete!"),
      description: Text("Congratulations on completing this level!"),
      actions: [
        shadcn.ShadButton(
          child: Text("Exit"),
          onPressed: () async {
            var sharedPreferences = await SharedPreferences.getInstance();
            playerProgressionController.savePlayerProgression(
              levelIndex: levelId,
              statistic: statistics,
              hasWon: completedLevel,
              preferences: sharedPreferences,
            );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class LevelDisplay extends HookWidget {
  const LevelDisplay({required this.onExitGame, super.key});

  final void Function() onExitGame;

  Future<void> openSettings(BuildContext context) async {
    var parentContext = context;
    await showDialog(
      context: context,
      builder: (context) {
        return shadcn.ShadDialog(
          title: Text("Menu"),
          child: Padding(
            padding: EdgeInsetsGeometry.all(32),
            child: shadcn.ShadButton(
              child: Text("Exit game"),
              onPressed: () {
                if (parentContext.mounted) {
                  Navigator.of(context).pop();
                  onExitGame();
                }
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var level = useListenableSelector(
      gameNotifier,
      () => gameNotifier.currentLevel,
    );

    var startTime = useListenableSelector(
      gameNotifier,
      () => gameNotifier.start,
    );
    var theme = shadcn.ShadTheme.of(context);

    var text = switch (level) {
      int level => "Level $level",
      null => "Casual game",
    };

    return Padding(
      padding: EdgeInsetsGeometry.all(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(child: Text(text, style: theme.textTheme.h2)),
          ),
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Visibility(
                  visible: startTime != null,
                  child: HookBuilder(
                    builder: (context) {
                      var currentTimeInSeconds = useState(0);
                      useEffect(() {
                        var timer = Timer.periodic(
                          Duration(seconds: 1),
                          (_) => currentTimeInSeconds.value = DateTime.now()
                              .difference(startTime!)
                              .abs()
                              .inSeconds,
                        );
                        return timer.cancel;
                      }, [startTime]);

                      return Text("Time: ${currentTimeInSeconds.value}");
                    },
                  ),
                ),
                shadcn.ShadIconButton(
                  icon: Icon(shadcn.LucideIcons.settings),
                  onPressed: () => openSettings(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Board extends HookWidget {
  const Board({super.key});

  Future<void> handleAction(
    BuildContext context,
    Player player,
    GameCard card,
  ) async {
    var game = gameNotifier.game;
    if (game.activePlayer == null) {
      var playerCompletedSetup =
          game.getPlayer(player).board.revealedCardCount == 2;
      if (playerCompletedSetup) return;
      gameNotifier.updateGame((game) => game.flipInitialCard(player, card));
      return;
    }

    if (game.visibleCard != null) {
      if (card.revealed) {
        gameNotifier.updateGame((game) => game.tradeVisibleCard(player, card));
        return;
      }
      var result = await showDialog(
        context: context,
        builder: (context) => TradeOrFlipDialog(),
      );
      if (result == true) {
        gameNotifier.updateGame((game) => game.tradeVisibleCard(player, card));
      }
      if (result == false) {
        gameNotifier.updateGame((game) => game.flipCard(player, card));
      }
    } else {
      var result = await showDialog(
        context: context,
        builder: (context) => TradeDiscardDialog(card: card),
      );
      if (result != true) return;
      gameNotifier.updateGame((game) => game.tradeDiscard(player, card));
    }
  }

  @override
  Widget build(BuildContext context) {
    var ownBoard = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.ownPlayer.board,
    );
    var opponentBoard = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.opponent.board,
    );
    var opponentTurn = useListenableSelector(
      gameNotifier,
      () =>
          gameNotifier.game.activePlayer == null ||
          gameNotifier.game.activePlayer?.id ==
              gameNotifier.game.opponent.player.id,
    );
    var ownTurn = useListenableSelector(
      gameNotifier,
      () =>
          gameNotifier.game.activePlayer == null ||
          gameNotifier.game.activePlayer?.id ==
              gameNotifier.game.ownPlayer.player.id,
    );
    var vsPlayer = useListenableSelector(
      gameNotifier,
      () => !gameNotifier.cpuEnabled,
    );
    return Column(
      children: [
        Expanded(
          child: AnimatedRotation(
            duration: Duration(milliseconds: 500),
            turns: vsPlayer ? 0.5 : 0,
            child: PlayerBoardDisplay(
              isActive: opponentTurn,
              playerBoard: opponentBoard,
              onTapCard: (card) async {
                if (!vsPlayer) return;
                if (!opponentTurn) return;
                var player = gameNotifier.game.opponent.player;
                await handleAction(context, player, card);
              },
            ),
          ),
        ),
        SizedBox(height: 140, child: TurnPlayerRotator(child: CardPiles())),
        Expanded(
          child: PlayerBoardDisplay(
            playerBoard: ownBoard,
            isActive: ownTurn,
            onTapCard: (card) async {
              if (!ownTurn) return;
              var player = gameNotifier.game.ownPlayer.player;
              await handleAction(context, player, card);
            },
          ),
        ),
      ],
    );
  }
}

class DrawCardDialog extends StatelessWidget {
  const DrawCardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    var body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          TappableGameCard(gameCard: gameNotifier.game.discard.last),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              "You would not be able to use this card from the discard pile anymore",
            ),
          ),
        ],
      ),
    );

    var dialog = shadcn.ShadDialog(
      actionsMainAxisAlignment: MainAxisAlignment.center,
      title: Text("Draw a card?"),
      description: body,
      actions: [
        shadcn.ShadButton(
          child: Text("Yes"),
          onPressed: () => Navigator.pop(context, true),
        ),
        shadcn.ShadButton(
          child: Text("No"),
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    );

    return TurnPlayerRotator(child: dialog);
  }
}

class TradeOrFlipDialog extends StatelessWidget {
  const TradeOrFlipDialog({super.key});

  @override
  Widget build(BuildContext context) {
    var body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(true),
                child: shadcn.ShadCard(
                  child: Center(
                    child: Column(
                      spacing: 8,
                      children: [
                        TappableGameCard(
                          gameCard: gameNotifier.game.visibleCard!,
                        ),
                        Icon(Icons.sync_alt_rounded, size: 40),
                        Text("Replace"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: shadcn.ShadCard(
                  child: Center(
                    child: Column(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TappableGameCard(
                          gameCard: GameCard(value: 0, revealed: false),
                        ),
                        Icon(Icons.remove_red_eye_rounded, size: 40),
                        Text("Reveal"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    var dialog = shadcn.ShadDialog(
      backgroundColor: shadcn.ShadTheme.of(
        context,
      ).colorScheme.background.withValues(alpha: 0.6),
      closeIcon: null,
      actionsMainAxisAlignment: MainAxisAlignment.center,
      title: Text("Reveal or Replace?"),
      description: body,
    );
    return TurnPlayerRotator(child: dialog);
  }
}

class TradeDiscardDialog extends StatelessWidget {
  const TradeDiscardDialog({required this.card, super.key});

  final GameCard card;

  @override
  Widget build(BuildContext context) {
    var body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Column(
            children: [
              Text("Discard"),
              TappableGameCard(gameCard: gameNotifier.game.discard.last),
            ],
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Icon(Icons.sync_alt_rounded, size: 40),
                Text("This will replace your card"),
              ],
            ),
          ),
          SizedBox(width: 16),
          Column(
            children: [
              Text("Your card"),
              TappableGameCard(gameCard: card),
            ],
          ),
        ],
      ),
    );

    var dialog = shadcn.ShadDialog(
      closeIcon: null,
      title: Text("Replace with Discard?"),
      actionsMainAxisAlignment: MainAxisAlignment.center,
      description: body,
      actions: [
        shadcn.ShadButton(
          child: Text("Yes"),
          onPressed: () => Navigator.pop(context, true),
        ),
        shadcn.ShadButton(
          child: Text("No"),
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    );

    return TurnPlayerRotator(child: dialog);
  }
}

class CardPiles extends HookWidget {
  const CardPiles({super.key});

  @override
  Widget build(BuildContext context) {
    var discard = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.discard,
    );
    var deck = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.deck,
    );
    var visibleCard = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.visibleCard,
    );
    var canDrawCard =
        visibleCard == null && gameNotifier.game.activePlayer != null;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Discard"),
              SizedBox(height: 20),
              TappableGameCard(
                gameCard: discard.last,
                highLighted: canDrawCard,
              ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Deck"),
              SizedBox(height: 20),
              TappableGameCard(
                gameCard: visibleCard ?? deck.last,
                highLighted: visibleCard != null,
                onTapCard: (card) async {
                  if (!canDrawCard) return;
                  var result = await showDialog(
                    context: context,
                    builder: (context) => DrawCardDialog(),
                  );
                  if (result == true) {
                    gameNotifier.updateGame(
                      (game) => game.drawCard(game.activePlayer!),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayerBoardDisplay extends HookWidget {
  const PlayerBoardDisplay({
    required this.playerBoard,
    required this.onTapCard,
    required this.isActive,
    super.key,
  });

  final PlayerBoard playerBoard;
  final bool isActive;

  final Future<void> Function(GameCard card) onTapCard;

  @override
  Widget build(BuildContext context) {
    var cardTapped = useState<String?>(null);

    Future<void> onTapCard(GameCard card) async {
      cardTapped.value = card.id;
      try {
        await this.onTapCard(card);
      } finally {
        cardTapped.value = null;
      }
    }

    return AnimatedOpacity(
      duration: Duration(milliseconds: 300),
      opacity: isActive ? 1.0 : 0.6,
      child: Row(
        children: [
          for (var column in playerBoard.columns) ...[
            Expanded(
              child: Column(
                children: [
                  for (var gameCard in column.cards) ...[
                    Expanded(
                      child: Center(
                        child: TappableGameCard(
                          gameCard: gameCard,
                          onTapCard: onTapCard,
                          highLighted: cardTapped.value == gameCard.id,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TappableGameCard extends StatelessWidget {
  const TappableGameCard({
    required this.gameCard,
    this.onTapCard,
    this.highLighted = false,
    super.key,
  });

  final GameCard gameCard;
  final bool highLighted;
  final void Function(GameCard card)? onTapCard;

  Color getColorForValue() {
    if (!gameCard.revealed) {
      return Colors.amber;
    }

    return switch (gameCard.value) {
      < 0 => Colors.deepPurple,
      < 5 => Colors.blueAccent,
      < 9 => Colors.green,
      _ => Colors.redAccent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(100, 60)),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTapCard == null ? null : () => onTapCard?.call(gameCard),
          child: shadcn.ShadCard(
            padding: EdgeInsets.zero,
            backgroundColor: getColorForValue(),
            border: !highLighted
                ? null
                : Border.all(color: Colors.white, width: 2.5),
            child: Center(
              child: switch (gameCard.revealed) {
                true => Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      "${gameCard.value}",
                      style: TextStyle(color: Colors.black, fontSize: 20),
                    ),
                  ),
                ),
                false => Icon(Icons.error),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class GameHeader extends HookWidget {
  const GameHeader({super.key});

  @override
  Widget build(BuildContext context) {
    var ownPlayer = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.ownPlayer,
    );
    var opponent = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.opponent,
    );
    var currentPlayer = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.activePlayer,
    );
    var round = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.round,
    );
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: ScoreCard(
            label: ownPlayer.player.name,
            color: ownPlayer.player.color,
            isActive: ownPlayer.player.id == currentPlayer?.id,
            value: ownPlayer.points,
            outOf: ownPlayer.pointTarget,
          ),
        ),
        Spacer(),
        ScoreCard(label: "Round", value: round, isLarge: true),
        Spacer(),
        SizedBox(
          width: 120,
          child: ScoreCard(
            label: opponent.player.name,
            color: opponent.player.color,
            isActive: opponent.player.id == currentPlayer?.id,
            value: opponent.points,
            outOf: opponent.pointTarget,
          ),
        ),
      ],
    );
  }
}

class ScoreCard extends StatelessWidget {
  const ScoreCard({
    required this.label,
    required this.value,
    this.isActive = false,
    this.isLarge = false,
    this.color,
    this.outOf,
    super.key,
  });

  final String label;
  final bool isActive;
  final num value;
  final num? outOf;
  final Color? color;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    var theme = shadcn.ShadTheme.of(context);

    var text = "$value";
    if (outOf != null) {
      text = "$text / $outOf";
    }
    return shadcn.ShadCard(
      backgroundColor: color?.withValues(alpha: 0.4),
      child: Column(
        children: [
          Text(
            label,
            style: switch (isActive) {
              false => theme.textTheme.lead,
              true => theme.textTheme.lead.copyWith(
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2.0)],
              ),
            },
          ),
          Text(
            text,
            style: switch (isLarge) {
              false => theme.textTheme.large,
              true => theme.textTheme.h2,
            },
          ),
          if (outOf != null) ...[
            shadcn.ShadProgress(value: (value / outOf!).clamp(0, 1.0)),
          ],
        ],
      ),
    );
  }
}

class TurnPlayerRotator extends HookWidget {
  const TurnPlayerRotator({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var isOpponentPlayerTurn = useListenableSelector(
      gameNotifier,
      () =>
          gameNotifier.game.activePlayer == gameNotifier.game.opponent.player &&
          !gameNotifier.cpuEnabled,
    );
    return AnimatedRotation(
      turns: isOpponentPlayerTurn ? 0.5 : 0,
      duration: Duration(milliseconds: 500),
      child: child,
    );
  }
}
