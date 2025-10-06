import 'dart:math';

import 'package:reveal_duel/src/game/models.dart';

class GameAi {
  GameAi({
    required this.player,
    required this.initialFlipStrategy,
    required this.discardStrategy,
    required this.swapOrFlipStrategy,
  });

  final Player player;

  /// Strategy that determines the initial 2 flips
  final GameMoveStrategy initialFlipStrategy;

  /// Strategy that determines if the discard should be used or a draw should be made
  final GameMoveStrategy discardStrategy;

  /// Strategy that determines if a card should be swapped or flipped.
  final GameMoveStrategy swapOrFlipStrategy;

  Game determineMove(Game game) {
    var gamePlayer = game.getPlayer(player);
    if (game.activePlayer != null && game.activePlayer?.id != player.id) {
      return game;
    }
    if (game.state == GameState.setup) {
      return initialFlipStrategy(game, gamePlayer);
    }
    if (game.state == GameState.running) {
      if (game.visibleCard == null) {
        return discardStrategy(game, gamePlayer);
      } else {
        return swapOrFlipStrategy(game, gamePlayer);
      }
    }

    return game;
  }
}

typedef GameMoveStrategy = Game Function(Game, GamePlayer);

GameMoveStrategy randomFlipStrategy() => (Game game, GamePlayer player) {
  var random = game.random ?? Random();
  var columns = player.board.columns;

  GameCard? card;
  if (player.board.revealedCardCount >= 2) return game;
  while (card == null || card.revealed) {
    var columnIndex = random.nextInt(columns.length);
    var column = columns[columnIndex];

    var cardIndex = random.nextInt(column.cards.length);
    card = column.cards[cardIndex];
  }

  return game.flipInitialCard(player.player, card);
};

GameMoveStrategy fixedFlipStrategy(Point<int> position1, Point<int> position2) {
  assert(position1 != position2, "2 different points need to be provided");
  return (Game game, GamePlayer player) {
    var columns = player.board.columns;
    var card = columns[position1.x].cards[position1.y];

    if (card.revealed) {
      card = columns[position2.x].cards[position2.y];
    }

    if (card.revealed) {
      return game;
    }

    return game.flipInitialCard(player.player, card);
  };
}

Iterable<GameCard> _getRevealedCardsAboveValue(int value, PlayerBoard board) {
  var allRevealedCards = board.getAllRevealedCards();
  return allRevealedCards.where((card) => card.value > value);
}

GameMoveStrategy pickLowerDiscardStrategy(int minValueDifference) =>
    (game, player) {
      var value = game.discard.last.value;
      var targets = _getRevealedCardsAboveValue(
        value + minValueDifference,
        player.board,
      );
      if (targets.isEmpty) {
        return game.drawCard(player.player);
      }

      var targetCard = targets.reduce(
        (target, card) => target.value > card.value ? target : card,
      );

      return game.tradeDiscard(player.player, targetCard);
    };

GameMoveStrategy replaceBlankDiscardStrategy(
  int minValueDifference,
  int switchBlankValue,
) => (game, player) {
  var value = game.discard.last.value;
  if (value <= switchBlankValue) {
    var allHiddenCards = player.board.getAllHiddenCards();
    var cardIndex = Random().nextInt(allHiddenCards.length);
    var card = allHiddenCards[cardIndex];

    return game.tradeDiscard(player.player, card);
  }

  return pickLowerDiscardStrategy(minValueDifference)(game, player);
};

GameMoveStrategy swapOrFlipValueStrategy(int minValueDifference, [int minFlipValue = 4]) =>
    (game, player) {
      var visibleCard = game.visibleCard;
      if (visibleCard == null) return game;
      var value = visibleCard.value;

      var targets = _getRevealedCardsAboveValue(
        value + minValueDifference,
        player.board,
      );

      if (targets.isNotEmpty) {
        var targetCard = targets.reduce(
          (target, card) => target.value > card.value ? target : card,
        );

        return game.tradeVisibleCard(player.player, targetCard);
      }

      var allHiddenCards = player.board.getAllHiddenCards();
      var cardIndex = Random().nextInt(allHiddenCards.length);
      var card = allHiddenCards[cardIndex];

      if (value > minFlipValue) {
        return game.flipCard(player.player, card);
      }
      return game.tradeVisibleCard(player.player, card);
    };
