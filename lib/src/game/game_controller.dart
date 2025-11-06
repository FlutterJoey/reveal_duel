import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reveal_duel/src/game/game_ai.dart';
import 'package:reveal_duel/src/game/levels.dart';
import 'package:reveal_duel/src/game/models.dart';

class GameNotifier extends ChangeNotifier {
  GameNotifier() {
    Timer.periodic(Duration(milliseconds: 750), (_) {
      _tick();
    });
  }

  Game? _previousGame;
  void _tick() {
    if (!gameAvailable) return;
    updateGame((game) {
      if (_previousGame != game) {
        _previousGame = game;
        return game;
      }
      var updatedGame = cpuPlayers.fold(
        game,
        (game, cpu) => cpu.determineMove(game),
      );
      return updatedGame;
    });
  }

  Game? _game;
  int? currentLevel;
  List<RevealCPU> cpuPlayers = [];
  DateTime? start;

  bool get cpuEnabled => cpuPlayers.isNotEmpty;
  Game get game => _game!;
  late final Timer timer;

  bool get gameAvailable => _game != null;

  @override
  void notifyListeners() {
    Future.delayed(Duration.zero, () => super.notifyListeners());
  }

  void updateGame(Game Function(Game) gameAction) {
    var nextGame = gameAction(game);
    if (nextGame == _game) return;
    _game = nextGame;
    notifyListeners();
  }

  void reset() {
    _game = null;
    currentLevel = null;
    start = null;
    cpuPlayers.clear();
  }

  void setupCPUGame(Player player) {
    _game = Game.fresh(player, cpuPlayer, GameOptions.skipBo());
    cpuPlayers = [RevealCPU.simpleCpu];
    notifyListeners();
  }

  void setupPvPGame(Player player, Player opponent) {
    _game = Game.fresh(player, opponent, GameOptions.skipBo());
    cpuPlayers = [];
    notifyListeners();
  }

  void setupLevel(GameLevel level, Player player) {
    _game = Game.fromLevel(level, player).startRound();
    start = DateTime.now();
    currentLevel = level.level;
    cpuPlayers = [level.cpu];
    notifyListeners();
  }
}

final gameNotifier = GameNotifier();
