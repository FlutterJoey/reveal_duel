import 'dart:math';

import 'package:reveal_duel/src/game/models.dart';

final cpuPlayer = Player(name: "Computer", id: "cpu-1");

class RevealCPU {
  RevealCPU({
    required this.player,
    required this.initialFlipStrategy,
    required this.discardStrategy,
    required this.swapOrFlipStrategy,
  });

  static RevealCPU simpleCpu = RevealCPU(
    player: cpuPlayer,
    initialFlipStrategy: randomFlipStrategy(),
    discardStrategy: replaceBlankDiscardStrategy(2, 1),
    swapOrFlipStrategy: swapOrFlipValueStrategy(2),
  );

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

const flipStrategies = (
  fixedFlipStrategy: fixedFlipStrategy,
  randomFlipStrategy: randomFlipStrategy,
);

const discardStrategies = (
  alwaysDrawStrategy: alwaysDrawStrategy,
  pickLowerDiscardStrategy: pickLowerDiscardStrategy,
  alwaysTakeDiscardStrategy: alwaysTakeDiscardStrategy,
  replaceBlankDiscardStrategy: replaceBlankDiscardStrategy,
);

const swapFlipStrategies = (
  swapOrFlipValueStrategy: swapOrFlipValueStrategy,
  gamblerSwapStrategy: gamblerSwapStrategy,
  columnAwareSwapStrategy: columnAwareSwapStrategy,
);

GameMoveStrategy randomFlipStrategy() => (Game game, GamePlayer player) {
  var random = game.random;
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

GameMoveStrategy alwaysDrawStrategy() => (game, player) {
  return game.drawCard(player.player);
};

GameMoveStrategy alwaysTakeDiscardStrategy() => (game, player) {
  var allHiddenCards = player.board.getAllHiddenCards();
  if (allHiddenCards.isEmpty) {
    // Failsafe: if no hidden cards, swap with highest revealed
    return pickLowerDiscardStrategy(0)(game, player);
  }
  var cardIndex = game.random.nextInt(allHiddenCards.length);
  var card = allHiddenCards[cardIndex];
  return game.tradeDiscard(player.player, card);
};

GameMoveStrategy gamblerSwapStrategy() => (game, player) {
  var visibleCard = game.visibleCard;
  if (visibleCard == null) return game; // Should not happen

  var allHiddenCards = player.board.getAllHiddenCards();
  if (allHiddenCards.isEmpty) {
    // Failsafe: if no hidden cards, swap with highest revealed
    return swapOrFlipValueStrategy(0)(game, player);
  }

  var cardIndex = game.random.nextInt(allHiddenCards.length);
  var card = allHiddenCards[cardIndex];
  return game.tradeVisibleCard(player.player, card);
};

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
    var cardIndex = game.random.nextInt(allHiddenCards.length);
    var card = allHiddenCards[cardIndex];

    return game.tradeDiscard(player.player, card);
  }

  return pickLowerDiscardStrategy(minValueDifference)(game, player);
};

GameMoveStrategy swapOrFlipValueStrategy(
  int minValueDifference, [
  int minFlipValue = 4,
]) => (game, player) {
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
  var cardIndex = game.random.nextInt(allHiddenCards.length);
  var card = allHiddenCards[cardIndex];

  if (value > minFlipValue) {
    return game.flipCard(player.player, card);
  }
  return game.tradeVisibleCard(player.player, card);
};

GameMoveStrategy columnAwareDiscardStrategy({
  int fallbackReplaceThreshold = 2,
  int fallbackFlipValue = 4,
  int minStartColumnValue = 5,
  int minFinishColumnValue = 1,
}) => (game, player) {
  var visibleCard = game.discard.last;
  var value = visibleCard.value;

  var targetCard = _findColumnReplaceableCard(
    player: player,
    value: value,
    minStartColumnValue: minStartColumnValue,
    minFinishColumnValue: minFinishColumnValue,
  );
  if (targetCard != null) {
    return game.tradeDiscard(player.player, targetCard);
  }

  // No column ops, use default logic
  return replaceBlankDiscardStrategy(
    fallbackReplaceThreshold,
    fallbackFlipValue,
  )(game, player);
};

GameMoveStrategy columnAwareSwapStrategy({
  int fallbackReplaceThreshold = 2,
  int fallbackFlipValue = 4,
  int minStartColumnValue = 5,
  int minFinishColumnValue = 1,
}) => (game, player) {
  var visibleCard = game.visibleCard;
  if (visibleCard == null) return game;
  var value = visibleCard.value;

  var targetCard = _findColumnReplaceableCard(
    player: player,
    value: value,
    minStartColumnValue: minStartColumnValue,
    minFinishColumnValue: minFinishColumnValue,
  );
  if (targetCard != null) {
    return game.tradeVisibleCard(player.player, targetCard);
  }

  // No column ops, use default logic
  return swapOrFlipValueStrategy(fallbackReplaceThreshold, fallbackFlipValue)(
    game,
    player,
  );
};

GameCard? _findColumnReplaceableCard({
  required GamePlayer player,
  required int value,
  required int minStartColumnValue,
  required int minFinishColumnValue,
}) {
  for (var column in player.board.columns) {
    var revealedInCol = column.cards.where((c) => c.revealed).toList();
    var hiddenInCol = column.cards.where((c) => !c.revealed).toList();

    if (revealedInCol.length == 2 &&
        hiddenInCol.length == 1 &&
        revealedInCol[0].value == value &&
        revealedInCol[1].value == value &&
        value >= minFinishColumnValue) {
      return hiddenInCol.first;
    }

    if (revealedInCol.length == 1 &&
        hiddenInCol.length == 1 &&
        revealedInCol[0].value == value &&
        value >= minStartColumnValue) {
      return hiddenInCol.first;
    }
  }

  return null;
}

Iterable<GameCard> _getRevealedCardsAboveValue(int value, PlayerBoard board) {
  var allRevealedCards = board.getAllRevealedCards();
  return allRevealedCards.where((card) => card.value > value);
}
