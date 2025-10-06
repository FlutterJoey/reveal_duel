import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:reveal_duel/src/game/game_ai.dart';
import 'package:reveal_duel/src/game/models.dart';
import 'package:reveal_duel/src/util/uuid.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;

extension on Player {
  Color get color => Colors.primaries[id.hashCode % Colors.primaries.length];
}

class GameNotifier extends ChangeNotifier {
  GameNotifier()
    : _game = Game.fresh(
        Player(name: "Player 1", id: uuid.v4()),
        Player(name: "Player 2", id: uuid.v4()),
        GameOptions.skipBo(100),
      ) {
    ai = GameAi(
      player: _game.opponent.player,
      initialFlipStrategy: randomFlipStrategy(),
      discardStrategy: replaceBlankDiscardStrategy(2, 1),
      swapOrFlipStrategy: swapOrFlipValueStrategy(2),
    );

    Timer.periodic(Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    if (!aiEnabled) return;

    updateGame((game) => ai.determineMove(game));
  }

  Game _game;
  late GameAi ai;
  bool aiEnabled = false;
  Game get game => _game;
  late final Timer timer;

  void updateGame(Game Function(Game) gameAction) {
    _game = gameAction(_game);
    notifyListeners();
  }

  void toggleAi() {
    aiEnabled = !aiEnabled;
    notifyListeners();
  }

  void reset() {
    _game = Game.fresh(
      _game.ownPlayer.player,
      _game.opponent.player,
      _game.options,
    );
    notifyListeners();
  }
}

final gameNotifier = GameNotifier();

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          GameHeader(),
          SizedBox(height: 20),
          Divider(),
          SizedBox(height: 20),
          Expanded(child: Board()),
          SizedBox(height: 100, child: ControlButtons()),
        ],
      ),
    );
  }
}

class ControlButtons extends HookWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    var gameState = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.state,
    );

    var aiEnabled = useListenableSelector(
      gameNotifier,
      () => gameNotifier.aiEnabled,
    );
    return Padding(
      padding: EdgeInsetsGeometry.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          shadcn.ShadButton(
            enabled: gameState == GameState.finished,
            child: Text("Next round"),
            onPressed: () {
              gameNotifier.updateGame((game) => game.startNextRound());
            },
          ),
          shadcn.ShadButton(
            backgroundColor: aiEnabled ? Colors.green : Colors.red,
            enabled: [GameState.running, GameState.setup].contains(gameState),
            child: Text("AI"),
            onPressed: () {
              gameNotifier.toggleAi();
            },
          ),
          shadcn.ShadButton(
            child: Text("Reset"),
            onPressed: () {
              gameNotifier.reset();
            },
          ),
        ],
      ),
    );
  }
}

class Board extends HookWidget {
  const Board({super.key});

  void handleAction(BuildContext context, Player player, GameCard card) async {
    var game = gameNotifier.game;
    if (game.activePlayer == null) {
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
        builder: (context) => shadcn.ShadDialog(
          closeIcon: null,
          actions: [
            shadcn.ShadButton(
              child: Text("Replace"),
              onPressed: () => Navigator.pop(context, true),
            ),
            shadcn.ShadButton(
              child: Text("Flip"),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      );
      if (result == true) {
        gameNotifier.updateGame((game) => game.tradeVisibleCard(player, card));
      }
      if (result == false) {
        gameNotifier.updateGame((game) => game.flipCard(player, card));
      }
    } else {
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
    return Column(
      children: [
        Expanded(
          child: PlayerBoardDisplay(
            isActive: opponentTurn,
            playerBoard: opponentBoard,
            onTapCard: (card) {
              var player = gameNotifier.game.opponent.player;
              handleAction(context, player, card);
            },
          ),
        ),
        SizedBox(height: 140, child: CardPiles()),
        Expanded(
          child: PlayerBoardDisplay(
            playerBoard: ownBoard,
            isActive: ownTurn,
            onTapCard: (card) {
              var player = gameNotifier.game.ownPlayer.player;
              handleAction(context, player, card);
            },
          ),
        ),
      ],
    );
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
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Discard"),
              SizedBox(height: 20),
              TappableGameCard(gameCard: discard.last),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Deck"),
              SizedBox(height: 20),
              TappableGameCard(
                gameCard: visibleCard ?? deck.last,
                onTapCard: (card) {
                  if (visibleCard == null &&
                      gameNotifier.game.activePlayer != null) {
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

class PlayerBoardDisplay extends StatelessWidget {
  const PlayerBoardDisplay({
    required this.playerBoard,
    required this.onTapCard,
    required this.isActive,
    super.key,
  });

  final PlayerBoard playerBoard;
  final bool isActive;

  final void Function(GameCard card) onTapCard;

  @override
  Widget build(BuildContext context) {
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
  const TappableGameCard({required this.gameCard, this.onTapCard, super.key});

  final GameCard gameCard;
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
          onTap: () => onTapCard?.call(gameCard),
          child: shadcn.ShadCard(
            padding: EdgeInsets.zero,
            backgroundColor: getColorForValue(),
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
    var points = useListenableSelector(
      gameNotifier,
      () => gameNotifier.game.options.goal,
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
            outOf: points,
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
            outOf: points,
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
