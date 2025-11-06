
import 'package:flutter/widgets.dart';
import 'package:reveal_duel/src/game/models.dart';
import 'package:reveal_duel/src/util/uuid.dart';

class PlayerNotifier extends ChangeNotifier {
  Player _player = Player(name: "Player", id: uuid.v4());

  void updatePlayer(Player Function(Player) updatePlayer) {
    _player = updatePlayer(_player);
    notifyListeners();
  }

  Player get activePlayer => _player;
}

final playerNotifier = PlayerNotifier();