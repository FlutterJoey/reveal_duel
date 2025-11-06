import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:reveal_duel/src/game/game_ai.dart';
import 'package:reveal_duel/src/game/levels.dart';
import 'package:reveal_duel/src/util/uuid.dart';

class InvalidMoveException implements Exception {}

class PlayerBoard {
  PlayerBoard({required this.columns});
  PlayerBoard.empty() : columns = [];

  factory PlayerBoard.fromCards(
    List<GameCard> cards, [
    int columnCount = 4,
    int cardsPerColumn = 3,
  ]) {
    var columns = [
      for (int column = 0; column < columnCount; column++) ...[
        PlayerBoardColumn(
          cards: cards.sublist(
            column * cardsPerColumn,
            (column + 1) * cardsPerColumn,
          ),
        ),
      ],
    ];

    return PlayerBoard(columns: columns);
  }

  factory PlayerBoard.test() {
    return PlayerBoard(
      columns: [
        PlayerBoardColumn(
          cards: [GameCard(value: -2), GameCard(value: -1), GameCard(value: 0)],
        ),
        PlayerBoardColumn(
          cards: [GameCard(value: 1), GameCard(value: 2), GameCard(value: 3)],
        ),
        PlayerBoardColumn(
          cards: [GameCard(value: 4), GameCard(value: 5), GameCard(value: 6)],
        ),
        PlayerBoardColumn(
          cards: [GameCard(value: 7), GameCard(value: 8), GameCard(value: 9)],
        ),
      ],
    );
  }

  final List<PlayerBoardColumn> columns;

  int get revealedCardCount => columns.fold(
    0,
    (previous, column) => previous + column.revealedCardCount,
  );

  int get visibleScore =>
      columns.fold(0, (previous, column) => previous + column.visibleScore);

  (PlayerBoard, List<PlayerBoardColumn>) clearColumns() {
    var clearedColumns = columns.where((column) => column.allEquals()).toList();
    var board = PlayerBoard(
      columns: columns.where((column) => !column.allEquals()).toList(),
    );

    return (board, clearedColumns);
  }

  PlayerBoard flipCard(GameCard card) {
    return PlayerBoard(
      columns: columns.map((column) => column.flipCard(card)).toList(),
    );
  }

  PlayerBoard replaceCard(GameCard card, GameCard cardToReplace) {
    return PlayerBoard(
      columns: columns
          .map((column) => column.replaceCard(card, cardToReplace))
          .toList(),
    );
  }

  bool allCardsRevealed() {
    return columns.every((column) => column.allCardsRevealed());
  }

  PlayerBoard flipAllCards() {
    return PlayerBoard(
      columns: columns.map((column) => column.flipAllCards()).toList(),
    );
  }

  List<GameCard> getAllRevealedCards() {
    return columns.fold(
      [],
      (result, column) => [
        ...result,
        ...column.cards.where((card) => card.revealed),
      ],
    );
  }

  List<GameCard> getAllHiddenCards() {
    return columns.fold(
      [],
      (result, column) => [
        ...result,
        ...column.cards.where((card) => !card.revealed),
      ],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PlayerBoard && listEquals(other.columns, columns);
  }

  @override
  int get hashCode => columns.hashCode;
}

class PlayerBoardColumn {
  final List<GameCard> cards;

  PlayerBoardColumn({required this.cards});

  int get revealedCardCount => cards.fold(
    0,
    (previous, card) => card.revealed ? previous + 1 : previous,
  );

  int get visibleScore => cards.fold(
    0,
    (previous, card) => card.revealed ? previous + card.value : previous,
  );

  PlayerBoardColumn replaceCard(GameCard newCard, GameCard cardToReplace) {
    return PlayerBoardColumn(
      cards: cards.map((card) {
        if (card.id == cardToReplace.id) {
          return newCard;
        }
        return card;
      }).toList(),
    );
  }

  PlayerBoardColumn flipCard(GameCard cardToChange) {
    return PlayerBoardColumn(
      cards: cards.map((card) {
        if (card.id == cardToChange.id) {
          return card.revealCard();
        }
        return card;
      }).toList(),
    );
  }

  bool allEquals() =>
      cards.length > 1 &&
      cards.every((card) => card.value == cards.first.value && card.revealed);

  bool allCardsRevealed() => cards.every((card) => card.revealed);

  PlayerBoardColumn flipAllCards() {
    return PlayerBoardColumn(
      cards: cards.map((card) => card.revealCard()).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PlayerBoardColumn && listEquals(other.cards, cards);
  }

  @override
  int get hashCode => cards.hashCode;
}

class GameCard {
  GameCard({required this.value, this.revealed = false}) : id = uuid.v4();
  GameCard._internal({
    required this.value,
    required this.revealed,
    required this.id,
  });
  final int value;
  final String id;
  final bool revealed;

  GameCard revealCard() {
    return GameCard._internal(id: id, value: value, revealed: true);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GameCard &&
        other.value == value &&
        other.id == id &&
        other.revealed == revealed;
  }

  @override
  int get hashCode => value.hashCode ^ id.hashCode ^ revealed.hashCode;
}

enum GameState { setup, running, roundFinished, finished }

class Game {
  Game({
    required this.deck,
    required this.discard,
    required this.activePlayer,
    required this.ownPlayer,
    required this.opponent,
    required this.visibleCard,
    required this.options,
    required this.round,
    required this.previousFinisher,
    required this.state,
    Random? random,
    List<GameEvent>? events,
    String? id,
  }) : id = id ?? uuid.v4(),
       events = events ?? [] {
    this.random = random ?? Random(uuid.hashCode);
  }

  factory Game.fresh(Player ownPlayer, Player opponent, GameOptions options) {
    return Game(
      deck: [],
      discard: [],
      activePlayer: null,
      previousFinisher: null,
      ownPlayer: GamePlayer.fresh(ownPlayer),
      opponent: GamePlayer.fresh(opponent),
      visibleCard: null,
      options: options,
      round: 0,
      state: GameState.setup,
    ).startRound();
  }

  factory Game.fromLevel(GameLevel level, Player player) {
    return Game(
      deck: [],
      discard: [],
      activePlayer: null,
      ownPlayer: GamePlayer(
        player: player,
        board: PlayerBoard.empty(),
        points: level.playerPointStartAmount,
        pointTarget: level.playerPointGoal,
        startCards: level.playerCards,
      ),
      opponent: GamePlayer(
        player: cpuPlayer,
        board: PlayerBoard.empty(),
        points: level.cpuPointStartAmount,
        pointTarget: level.cpuPointGoal,
        startCards: level.cpuCards,
      ),
      visibleCard: null,
      options: GameOptions.skipBo(),
      round: 0,
      previousFinisher: null,
      state: GameState.setup,
      random: Random(level.seed),
    );
  }

  final String id;

  final int round;

  final GameState state;

  final List<GameCard> deck;
  final List<GameCard> discard;

  final Player? activePlayer;
  final Player? previousFinisher;

  final GamePlayer ownPlayer;
  final GamePlayer opponent;

  final GameCard? visibleCard;
  final GameOptions options;

  final List<GameEvent> events;
  late final Random random;

  bool isFirstGame() => round == 1;

  static const cardsPerBoard = 12;

  Game startRound() {
    var deck = options.getCards()..shuffle(random);
    var playerStartCards = deck.takeCardsOfValue(ownPlayer.startCards);
    var cpuStartCards = deck.takeCardsOfValue(opponent.startCards);
    var ownBoard = PlayerBoard.fromCards([
      ...playerStartCards,
      ...List.generate(
        cardsPerBoard - playerStartCards.length,
        (_) => deck.removeLast(),
      ),
    ]);
    var opponentBoard = PlayerBoard.fromCards([
      ...cpuStartCards,
      ...List.generate(
        cardsPerBoard - cpuStartCards.length,
        (_) => deck.removeLast(),
      ),
    ]);
    return Game(
      deck: deck,
      discard: [deck.removeLast().revealCard()],
      activePlayer: null,
      ownPlayer: ownPlayer.updateBoard((_) => ownBoard),
      opponent: opponent.updateBoard((_) => opponentBoard),
      visibleCard: null,
      previousFinisher: previousFinisher,
      options: options,
      round: round + 1,
      id: id,
      events: events,
      state: GameState.setup,
    );
  }

  void _checkIsActivePlayer(Player player) {
    if (player.id != activePlayer?.id) {
      throw InvalidMoveException();
    }
  }

  Game drawCard(Player player) {
    checkState(GameState.running);
    _checkIsActivePlayer(player);
    if (visibleCard != null) throw InvalidMoveException();
    var newDeck = List<GameCard>.from(deck);
    var drawnCard = newDeck.removeLast();
    return copyWith(deck: newDeck, visibleCard: (drawnCard.revealCard(),));
  }

  Game tradeDiscard(Player player, GameCard card) {
    checkState(GameState.running);
    if (visibleCard != null) throw InvalidMoveException();
    _checkIsActivePlayer(player);
    var gamePlayer = getPlayer(player);
    var newDiscard = List<GameCard>.from(discard);
    var topDiscard = newDiscard.removeLast();
    newDiscard.add(card.revealCard());
    var updatedPlayer = gamePlayer.updateBoard(
      (oldBoard) => oldBoard.replaceCard(topDiscard, card),
    );
    return copyWith(
      discard: newDiscard,
    ).updatePlayer(gamePlayer, updatedPlayer).switchTurn();
  }

  Game flipCard(Player player, GameCard card) {
    checkState(GameState.running);
    if (visibleCard == null) throw InvalidMoveException();
    _checkIsActivePlayer(player);
    var gamePlayer = getPlayer(player);
    var updatedPlayer = gamePlayer.updateBoard((board) => board.flipCard(card));
    return copyWith(
      discard: List<GameCard>.from(discard)..add(visibleCard!),
    ).updatePlayer(gamePlayer, updatedPlayer).clearVisibileCard().switchTurn();
  }

  Game tradeVisibleCard(Player player, GameCard card) {
    checkState(GameState.running);
    if (visibleCard == null) throw InvalidMoveException();
    _checkIsActivePlayer(player);
    var gamePlayer = getPlayer(player);

    var updatedPlayer = gamePlayer.updateBoard(
      (board) => board.replaceCard(visibleCard!, card),
    );
    return copyWith(
      discard: List<GameCard>.from(discard)..add(card.revealCard()),
    ).updatePlayer(gamePlayer, updatedPlayer).clearVisibileCard().switchTurn();
  }

  Game checkRoundEnd() {
    var gamePlayer = getPlayer(activePlayer!);
    if (!gamePlayer.board.allCardsRevealed()) return this;

    Game allCardsFlipped = flipAllNoneVisibleCards();

    var ownPlayerScore = allCardsFlipped.ownPlayer.board.visibleScore;
    var opponentScore = allCardsFlipped.opponent.board.visibleScore;

    if (ownPlayerScore > 0 &&
        ownPlayerScore > opponentScore &&
        allCardsFlipped.ownPlayer.player.id == activePlayer?.id) {
      ownPlayerScore *= 2;
    }
    if (opponentScore > 0 &&
        opponentScore > ownPlayerScore &&
        allCardsFlipped.opponent.player.id == activePlayer?.id) {
      opponentScore *= 2;
    }

    return allCardsFlipped
        .copyWith(
          ownPlayer: allCardsFlipped.ownPlayer.updatePoints(
            allCardsFlipped.ownPlayer.points + ownPlayerScore,
          ),
          opponent: allCardsFlipped.opponent.updatePoints(
            allCardsFlipped.opponent.points + opponentScore,
          ),
          previousFinisher: (activePlayer,),
          activePlayer: (null,),
          state: GameState.roundFinished,
        )
        .checkGameEnd();
  }

  void checkState(GameState state) {
    if (this.state != state) throw InvalidMoveException();
  }

  Game startNextRound() {
    checkState(GameState.roundFinished);

    return startRound();
  }

  Game flipAllNoneVisibleCards() {
    return updatePlayer(
      ownPlayer,
      ownPlayer.updateBoard((board) => board.flipAllCards()),
    ).updatePlayer(
      opponent,
      opponent.updateBoard((board) => board.flipAllCards()),
    );
  }

  Game determineStartingPlayer() {
    if (isFirstGame()) {
      var ownPlayerScore = ownPlayer.board.visibleScore;
      var opponentScore = opponent.board.visibleScore;

      if (ownPlayerScore > opponentScore) {
        return copyWith(
          activePlayer: (ownPlayer.player,),
          state: GameState.running,
        );
      } else {
        return copyWith(
          activePlayer: (opponent.player,),
          state: GameState.running,
        );
      }
    }
    return copyWith(
      activePlayer: (previousFinisher,),
      state: GameState.running,
    );
  }

  Game clearVisibileCard() => copyWith(visibleCard: (null,));

  Game switchTurn() {
    var nextTurn = switch (activePlayer) {
      null => determineStartingPlayer(),
      Player player when player.id == ownPlayer.player.id => copyWith(
        activePlayer: (opponent.player,),
      ),
      Player _ => copyWith(activePlayer: (ownPlayer.player,)),
    };

    return nextTurn.checkRoundEnd();
  }

  Game flipInitialCard(Player player, GameCard card) {
    if (activePlayer != null) throw InvalidMoveException();

    var gamePlayer = getPlayer(player);

    if (gamePlayer.board.revealedCardCount >= 2) throw InvalidMoveException();

    var updatedPlayer = gamePlayer.updateBoard((board) => board.flipCard(card));

    return updatePlayer(gamePlayer, updatedPlayer).checkSetupReady();
  }

  GamePlayer getWinner() {
    if (opponent.points > ownPlayer.points) {
      return ownPlayer;
    }

    return opponent;
  }

  Game checkGameEnd() {
    if (state != GameState.roundFinished) return this;

    if (!ownPlayer.reachedGoal() && !opponent.reachedGoal()) return this;

    return copyWith(state: GameState.finished);
  }

  Game checkSetupReady() {
    if (ownPlayer.board.revealedCardCount < 2 ||
        opponent.board.revealedCardCount < 2) {
      return this;
    }

    return determineStartingPlayer();
  }

  Game updatePlayer(GamePlayer player, GamePlayer updatedPlayer) {
    var (clearedBoard, columns) = updatedPlayer.board.clearColumns();
    updatedPlayer = updatedPlayer.updateBoard((_) => clearedBoard);
    var updatedDiscard = List<GameCard>.from(
      discard,
    )..addAll(columns.fold([], (cards, column) => [...cards, ...column.cards]));
    if (player == ownPlayer) {
      return copyWith(ownPlayer: updatedPlayer, discard: updatedDiscard);
    }
    if (player == opponent) {
      return copyWith(opponent: updatedPlayer, discard: updatedDiscard);
    }

    throw InvalidMoveException();
  }

  GamePlayer getPlayer(Player player) {
    if (ownPlayer.player.id == player.id) {
      return ownPlayer;
    }
    if (opponent.player.id == player.id) {
      return opponent;
    }

    throw InvalidMoveException();
  }

  Game copyWith({
    String? id,
    List<GameCard>? deck,
    List<GameCard>? discard,
    (Player?,)? activePlayer,
    (Player?,)? previousFinisher,
    GamePlayer? ownPlayer,
    GamePlayer? opponent,
    (GameCard?,)? visibleCard,
    GameOptions? options,
    int? round,
    List<GameEvent>? events,
    GameState? state,
  }) {
    return Game(
      id: id ?? this.id,
      deck: deck ?? this.deck,
      discard: discard ?? this.discard,
      activePlayer: activePlayer == null ? this.activePlayer : activePlayer.$1,
      previousFinisher: previousFinisher == null
          ? this.previousFinisher
          : previousFinisher.$1,
      ownPlayer: ownPlayer ?? this.ownPlayer,
      opponent: opponent ?? this.opponent,
      visibleCard: visibleCard == null ? this.visibleCard : visibleCard.$1,
      options: options ?? this.options,
      events: events ?? this.events,
      round: round ?? this.round,
      state: state ?? this.state,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Game &&
        other.id == id &&
        other.round == round &&
        other.state == state &&
        listEquals(other.deck, deck) &&
        listEquals(other.discard, discard) &&
        other.activePlayer == activePlayer &&
        other.previousFinisher == previousFinisher &&
        other.ownPlayer == ownPlayer &&
        other.opponent == opponent &&
        other.visibleCard == visibleCard &&
        other.options == options &&
        listEquals(other.events, events) &&
        other.random == random;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        round.hashCode ^
        state.hashCode ^
        deck.hashCode ^
        discard.hashCode ^
        activePlayer.hashCode ^
        previousFinisher.hashCode ^
        ownPlayer.hashCode ^
        opponent.hashCode ^
        visibleCard.hashCode ^
        options.hashCode ^
        events.hashCode ^
        random.hashCode;
  }
}

class GameEvent {
  final EventType type;
  final DateTime timestamp;
  final Player player;
  final GameCard? primaryCard;
  final GameCard? secondaryCard;

  GameEvent({
    required this.type,
    required this.timestamp,
    required this.player,
    this.primaryCard,
    this.secondaryCard,
  });
}

enum EventType {
  start,
  openCard,
  pickDiscard,
  placeCard,
  pickDeck,
  flipCard,
  clearColumn,
}

extension on List<GameCard> {
  List<GameCard> takeCardsOfValue(List<int> cards) {
    var cardsTaken = <GameCard>[];
    if (cards.isEmpty) return cardsTaken;
    for (var cardValue in cards.sublist(
      0,
      max(cards.length, Game.cardsPerBoard),
    )) {
      var card = where((card) => card.value == cardValue).firstOrNull;
      if (card == null) continue;
      remove(card);
      cardsTaken.add(card);
    }
    return cardsTaken;
  }
}

class GamePlayer {
  final Player player;
  final PlayerBoard board;
  final int points;
  final int pointTarget;
  final List<int> startCards;

  GamePlayer({
    required this.player,
    required this.board,
    required this.points,
    required this.pointTarget,
    required this.startCards,
  });

  GamePlayer.fresh(this.player)
    : board = PlayerBoard.empty(),
      points = 0,
      startCards = [],
      pointTarget = 100;

  GamePlayer updateBoard(PlayerBoard Function(PlayerBoard) update) =>
      copyWith(board: update(board));

  GamePlayer updatePoints(int points) => copyWith(points: points);

  GamePlayer copyWith({
    Player? player,
    PlayerBoard? board,
    int? points,
    int? pointTarget,
    List<int>? startCards,
  }) => GamePlayer(
    player: player ?? this.player,
    board: board ?? this.board,
    points: points ?? this.points,
    pointTarget: pointTarget ?? this.pointTarget,
    startCards: startCards ?? this.startCards,
  );

  bool reachedGoal() => points >= pointTarget;
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GamePlayer &&
        other.player == player &&
        other.board == board &&
        other.points == points &&
        other.pointTarget == pointTarget &&
        listEquals(other.startCards, startCards);
  }

  @override
  int get hashCode {
    return player.hashCode ^
        board.hashCode ^
        points.hashCode ^
        pointTarget.hashCode ^
        startCards.hashCode;
  }
}

class Player {
  final String name;
  final String id;

  Player({required this.name, required this.id});
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Player && other.name == name && other.id == id;
  }

  @override
  int get hashCode => name.hashCode ^ id.hashCode;
}

class GameOptions {
  final Map<int, int> gameCardDistribution;

  GameOptions({required this.gameCardDistribution});

  factory GameOptions.skipBo() {
    return GameOptions(
      gameCardDistribution: {
        ...{-2: 6, -1: 12, 0: 18},
        ...{1: 12, 2: 12, 3: 12, 4: 12},
        ...{5: 12, 6: 12, 7: 12, 8: 12},
        ...{9: 12, 10: 12},
      },
    );
  }

  List<GameCard> getCards() => [
    for (var MapEntry(key: card, value: amount) in gameCardDistribution.entries)
      ...List.generate(amount, (_) => GameCard(value: card)),
  ];
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GameOptions &&
        mapEquals(other.gameCardDistribution, gameCardDistribution);
  }

  @override
  int get hashCode => gameCardDistribution.hashCode;
}
