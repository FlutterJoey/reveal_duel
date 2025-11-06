import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reveal_duel/src/game/game_ai.dart';

class GameLevel {
  GameLevel({
    required this.level,
    required this.seed,
    required this.cpu,
    this.playerPointGoal = 100,
    this.playerPointStartAmount = 0,
    this.cpuPointGoal = 100,
    this.cpuPointStartAmount = 0,
    this.playerCards = const [],
    this.cpuCards = const [],
    this.timeout,
  });

  static List<(int, GameLevel)> getAllLevels() =>
      _levels.entries.map((entry) => (entry.key, entry.value)).toList();

  static GameLevel getById(int id) => _levels[id]!;

  final int level;

  final int playerPointGoal;
  final int playerPointStartAmount;
  final int cpuPointGoal;
  final int cpuPointStartAmount;

  final RevealCPU cpu;

  final List<int> playerCards;
  final List<int> cpuCards;

  final int seed;

  final Duration? timeout;
}

class PlayerProgression {
  final int playerLevel;

  final Map<int, LevelStatistic> levelStatistics;

  PlayerProgression({required this.playerLevel, required this.levelStatistics});

  factory PlayerProgression.fromMap(Map<String, dynamic> data) =>
      PlayerProgression(
        playerLevel: switch (data["level"]) {
          int level => level,
          _ => 1,
        },
        levelStatistics: switch (data["statistics"]) {
          Map<String, dynamic> statisticMap => statisticMap.map(
            (key, value) => MapEntry(int.parse(key), switch (value) {
              Map<String, dynamic> statistic => LevelStatistic.fromMap(
                statistic,
              ),
              _ => LevelStatistic.fromMap({}),
            }),
          ),
          _ => {},
        },
      );

  static const key = "player_progression";

  Map<String, dynamic> toMap() => {
    "level": playerLevel,
    "statistics": levelStatistics.map((level, statistic) {
      return MapEntry(level.toString(), statistic.toMap());
    }),
  };

  PlayerProgression updateStatistic(int level, LevelStatistic statistic) {
    return copyWith(
      levelStatistics: Map.from(levelStatistics)
        ..[level] = levelStatistics[level]?.join(statistic) ?? statistic,
    );
  }

  PlayerProgression copyWith({
    int? playerLevel,
    Map<int, LevelStatistic>? levelStatistics,
  }) {
    return PlayerProgression(
      playerLevel: playerLevel ?? this.playerLevel,
      levelStatistics: levelStatistics ?? this.levelStatistics,
    );
  }
}

Future<PlayerProgression> getPlayerProgression(
  SharedPreferences preferences,
) async {
  var data = preferences.getString(PlayerProgression.key);
  if (data != null) {
    return PlayerProgression.fromMap(jsonDecode(data));
  }

  return PlayerProgression(playerLevel: 1, levelStatistics: {});
}

class PlayerProgressionController extends ChangeNotifier {
  late PlayerProgression _progression;

  Future<void> load(SharedPreferences preferences) async {
    _progression = await getPlayerProgression(preferences);
  }

  Future<void> savePlayerProgression({
    required int levelIndex,
    required LevelStatistic statistic,
    required bool hasWon,
    required SharedPreferences preferences,
  }) async {
    var progression = _progression;
    if (levelIndex == progression.playerLevel) {
      progression = progression.copyWith(
        playerLevel: progression.playerLevel + 1,
      );
    }
    _progression = progression;
    unawaited(
      preferences.setString(
        PlayerProgression.key,
        jsonEncode(_progression.toMap()),
      ),
    );
    notifyListeners();
  }

  int getLevel() {
    return _progression.playerLevel;
  }
}

final playerProgressionController = PlayerProgressionController();

class LevelStatistic {
  /// The score difference between the opponent and the player.
  final int bestPlayerScore;

  /// The fastest time for the player to complete the level
  final Duration bestTime;

  LevelStatistic({required this.bestPlayerScore, required this.bestTime});

  factory LevelStatistic.fromMap(Map<String, dynamic> data) {
    return LevelStatistic(
      bestPlayerScore: data["score"] as int? ?? 0,
      bestTime: switch (data["time"]) {
        int millis => Duration(milliseconds: millis),
        _ => Duration.zero,
      },
    );
  }

  LevelStatistic join(LevelStatistic other) {
    return LevelStatistic(
      bestPlayerScore: max(other.bestPlayerScore, bestPlayerScore),
      bestTime: bestTime,
    );
  }

  Map<String, dynamic> toMap() => {
    "time": bestTime.inMilliseconds,
    "score": bestPlayerScore,
  };
}

final veryEasyCpu = RevealCPU(
  player: cpuPlayer,
  initialFlipStrategy: randomFlipStrategy(),
  discardStrategy: alwaysDrawStrategy(),
  swapOrFlipStrategy: swapOrFlipValueStrategy(4, 8),
);

final simpleCpu = RevealCPU(
  player: cpuPlayer,
  initialFlipStrategy: randomFlipStrategy(),
  discardStrategy: replaceBlankDiscardStrategy(2, 1),
  swapOrFlipStrategy: swapOrFlipValueStrategy(2),
);

final gamblerCpu = RevealCPU(
  player: cpuPlayer,
  initialFlipStrategy: randomFlipStrategy(),
  discardStrategy: alwaysTakeDiscardStrategy(),
  swapOrFlipStrategy: gamblerSwapStrategy(),
);

final smartCpu = RevealCPU(
  player: cpuPlayer,
  initialFlipStrategy: randomFlipStrategy(),
  discardStrategy: replaceBlankDiscardStrategy(1, 0),
  swapOrFlipStrategy: swapOrFlipValueStrategy(1, 3),
);

final columnAwareCpu = RevealCPU(
  player: cpuPlayer,
  initialFlipStrategy: randomFlipStrategy(),
  discardStrategy: columnAwareDiscardStrategy(
    fallbackReplaceThreshold: 2,
    fallbackFlipValue: 1,
  ),
  swapOrFlipStrategy: columnAwareSwapStrategy(
    fallbackReplaceThreshold: 2,
    fallbackFlipValue: 3,
  ),
);

final perfectCpu = RevealCPU(
  player: cpuPlayer,
  initialFlipStrategy: randomFlipStrategy(),
  discardStrategy: columnAwareDiscardStrategy(
    fallbackReplaceThreshold: 1,
    fallbackFlipValue: 0,
  ),
  swapOrFlipStrategy: columnAwareSwapStrategy(
    fallbackReplaceThreshold: 1,
    fallbackFlipValue: 3,
  ),
);

final Map<int, GameLevel> _levels = {
  // Phase 1: The Tutorial
  1: GameLevel(
    level: 1,
    seed: 1001,
    cpu: veryEasyCpu,
    playerPointGoal: 100,
    playerCards: [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5],
  ),
  2: GameLevel(level: 2, seed: 1002, cpu: veryEasyCpu, playerPointGoal: 100),
  3: GameLevel(level: 3, seed: 1003, cpu: veryEasyCpu, playerPointGoal: 95),
  4: GameLevel(level: 4, seed: 1004, cpu: veryEasyCpu, playerPointGoal: 90),
  5: GameLevel(level: 5, seed: 1005, cpu: veryEasyCpu, playerPointGoal: 85),
  6: GameLevel(level: 6, seed: 1006, cpu: veryEasyCpu, playerPointGoal: 80),
  7: GameLevel(level: 7, seed: 1007, cpu: veryEasyCpu, playerPointGoal: 80),
  8: GameLevel(level: 8, seed: 1008, cpu: veryEasyCpu, playerPointGoal: 75),
  9: GameLevel(level: 9, seed: 1009, cpu: veryEasyCpu, playerPointGoal: 75),
  10: GameLevel(
    level: 10,
    seed: 1010,
    cpu: veryEasyCpu,
    playerPointGoal: 70,
    cpuCards: [12, 12, 11, 11, 10, 10, 9, 9, 8, 8, 7, 7],
  ),
  11: GameLevel(level: 11, seed: 1011, cpu: veryEasyCpu, playerPointGoal: 70),
  12: GameLevel(level: 12, seed: 1012, cpu: veryEasyCpu, playerPointGoal: 65),
  13: GameLevel(level: 13, seed: 1013, cpu: simpleCpu, playerPointGoal: 70),
  14: GameLevel(level: 14, seed: 1014, cpu: simpleCpu, playerPointGoal: 65),
  15: GameLevel(
    level: 15,
    seed: 1015,
    cpu: simpleCpu,
    playerPointGoal: 100,
    playerPointStartAmount: 50,
  ),
  16: GameLevel(level: 16, seed: 1016, cpu: simpleCpu, playerPointGoal: 60),
  17: GameLevel(level: 17, seed: 1017, cpu: simpleCpu, playerPointGoal: 60),
  18: GameLevel(level: 18, seed: 1018, cpu: simpleCpu, playerPointGoal: 55),
  19: GameLevel(level: 19, seed: 1019, cpu: simpleCpu, playerPointGoal: 55),
  20: GameLevel(
    level: 20,
    seed: 1020,
    cpu: simpleCpu,
    playerPointGoal: 50,
    playerCards: [5, 5, -1, 8, 8, -1, 4, 4, -1, 2, 2, -1],
  ),

  // Phase 2: Score Challenge
  21: GameLevel(level: 21, seed: 1021, cpu: simpleCpu, playerPointGoal: 50),
  22: GameLevel(level: 22, seed: 1022, cpu: simpleCpu, playerPointGoal: 48),
  23: GameLevel(level: 23, seed: 1023, cpu: simpleCpu, playerPointGoal: 46),
  24: GameLevel(level: 24, seed: 1024, cpu: simpleCpu, playerPointGoal: 44),
  25: GameLevel(level: 25, seed: 1025, cpu: simpleCpu, playerPointGoal: 42),
  26: GameLevel(level: 26, seed: 1026, cpu: simpleCpu, playerPointGoal: 40),
  27: GameLevel(level: 27, seed: 1027, cpu: simpleCpu, playerPointGoal: 40),
  28: GameLevel(level: 28, seed: 1028, cpu: simpleCpu, playerPointGoal: 38),
  29: GameLevel(level: 29, seed: 1029, cpu: simpleCpu, playerPointGoal: 36),
  30: GameLevel(
    level: 30,
    seed: 1030,
    cpu: simpleCpu,
    playerPointGoal: 50,
    playerPointStartAmount: 20,
  ),
  31: GameLevel(level: 31, seed: 1031, cpu: simpleCpu, playerPointGoal: 34),
  32: GameLevel(level: 32, seed: 1032, cpu: simpleCpu, playerPointGoal: 34),
  33: GameLevel(level: 33, seed: 1033, cpu: simpleCpu, playerPointGoal: 32),
  34: GameLevel(level: 34, seed: 1034, cpu: simpleCpu, playerPointGoal: 32),
  35: GameLevel(
    level: 35,
    seed: 1035,
    cpu: simpleCpu,
    playerPointGoal: 40,
    playerPointStartAmount: 10,
  ),
  36: GameLevel(level: 36, seed: 1036, cpu: simpleCpu, playerPointGoal: 30),
  37: GameLevel(level: 37, seed: 1037, cpu: simpleCpu, playerPointGoal: 30),
  38: GameLevel(level: 38, seed: 1038, cpu: simpleCpu, playerPointGoal: 28),
  39: GameLevel(level: 39, seed: 1039, cpu: simpleCpu, playerPointGoal: 28),
  40: GameLevel(level: 40, seed: 1040, cpu: simpleCpu, playerPointGoal: 25),
  // Phase 3: The "Gambler"
  41: GameLevel(level: 41, seed: 1041, cpu: gamblerCpu, playerPointGoal: 60),
  42: GameLevel(level: 42, seed: 1042, cpu: gamblerCpu, playerPointGoal: 58),
  43: GameLevel(level: 43, seed: 1043, cpu: gamblerCpu, playerPointGoal: 56),
  44: GameLevel(level: 44, seed: 1044, cpu: gamblerCpu, playerPointGoal: 54),
  45: GameLevel(level: 45, seed: 1045, cpu: gamblerCpu, playerPointGoal: 52),
  46: GameLevel(level: 46, seed: 1046, cpu: gamblerCpu, playerPointGoal: 50),
  47: GameLevel(level: 47, seed: 1047, cpu: gamblerCpu, playerPointGoal: 50),
  48: GameLevel(level: 48, seed: 1048, cpu: gamblerCpu, playerPointGoal: 48),
  49: GameLevel(level: 49, seed: 1049, cpu: gamblerCpu, playerPointGoal: 48),
  50: GameLevel(
    level: 50,
    seed: 1050,
    cpu: gamblerCpu,
    playerPointGoal: 45,
    cpuCards: [-2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  ),
  51: GameLevel(level: 51, seed: 1051, cpu: gamblerCpu, playerPointGoal: 46),
  52: GameLevel(level: 52, seed: 1052, cpu: gamblerCpu, playerPointGoal: 44),
  53: GameLevel(level: 53, seed: 1053, cpu: gamblerCpu, playerPointGoal: 44),
  54: GameLevel(level: 54, seed: 1054, cpu: gamblerCpu, playerPointGoal: 42),
  55: GameLevel(
    level: 55,
    seed: 1055,
    cpu: gamblerCpu,
    playerPointGoal: 60,
    cpuCards: [12, 12, 12, 11, 11, 10, 10, 9, 9, 8, 8, 7],
  ),
  56: GameLevel(level: 56, seed: 1056, cpu: gamblerCpu, playerPointGoal: 40),
  57: GameLevel(level: 57, seed: 1057, cpu: gamblerCpu, playerPointGoal: 40),
  58: GameLevel(level: 58, seed: 1058, cpu: gamblerCpu, playerPointGoal: 38),
  59: GameLevel(level: 59, seed: 1059, cpu: gamblerCpu, playerPointGoal: 35),
  60: GameLevel(level: 60, seed: 1060, cpu: gamblerCpu, playerPointGoal: 30),

  // Phase 4: The "Smart" CPU
  61: GameLevel(level: 61, seed: 1061, cpu: smartCpu, playerPointGoal: 40),
  62: GameLevel(level: 62, seed: 1062, cpu: smartCpu, playerPointGoal: 39),
  63: GameLevel(level: 63, seed: 1063, cpu: smartCpu, playerPointGoal: 38),
  64: GameLevel(level: 64, seed: 1064, cpu: smartCpu, playerPointGoal: 37),
  65: GameLevel(level: 65, seed: 1065, cpu: smartCpu, playerPointGoal: 36),
  66: GameLevel(level: 66, seed: 1066, cpu: smartCpu, playerPointGoal: 35),
  67: GameLevel(level: 67, seed: 1067, cpu: smartCpu, playerPointGoal: 34),
  68: GameLevel(level: 68, seed: 1068, cpu: smartCpu, playerPointGoal: 33),
  69: GameLevel(level: 69, seed: 1069, cpu: smartCpu, playerPointGoal: 32),
  70: GameLevel(
    level: 70,
    seed: 1070,
    cpu: smartCpu,
    playerPointGoal: 30,
    cpuCards: [-2, -1, 0, 1, 2, 3, -2, -1, 0, 1, 2, 3],
  ),
  71: GameLevel(level: 71, seed: 1071, cpu: smartCpu, playerPointGoal: 30),
  72: GameLevel(level: 72, seed: 1072, cpu: smartCpu, playerPointGoal: 28),
  73: GameLevel(level: 73, seed: 1073, cpu: smartCpu, playerPointGoal: 28),
  74: GameLevel(level: 74, seed: 1074, cpu: smartCpu, playerPointGoal: 26),
  75: GameLevel(
    level: 75,
    seed: 1075,
    cpu: smartCpu,
    playerPointGoal: 40,
    playerPointStartAmount: 20,
  ),
  76: GameLevel(level: 76, seed: 1076, cpu: smartCpu, playerPointGoal: 25),
  77: GameLevel(level: 77, seed: 1077, cpu: smartCpu, playerPointGoal: 25),
  78: GameLevel(level: 78, seed: 1078, cpu: smartCpu, playerPointGoal: 22),
  79: GameLevel(level: 79, seed: 1079, cpu: smartCpu, playerPointGoal: 20),
  80: GameLevel(
    level: 80,
    seed: 1080,
    cpu: smartCpu,
    playerPointGoal: -1,
    cpuCards: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  ),

  // Phase 5: The Column Master
  81: GameLevel(
    level: 81,
    seed: 1081,
    cpu: columnAwareCpu,
    playerPointGoal: 50,
  ),
  82: GameLevel(
    level: 82,
    seed: 1082,
    cpu: columnAwareCpu,
    playerPointGoal: 48,
  ),
  83: GameLevel(
    level: 83,
    seed: 1083,
    cpu: columnAwareCpu,
    playerPointGoal: 46,
  ),
  84: GameLevel(
    level: 84,
    seed: 1084,
    cpu: columnAwareCpu,
    playerPointGoal: 44,
  ),
  85: GameLevel(
    level: 85,
    seed: 1085,
    cpu: columnAwareCpu,
    playerPointGoal: 42,
    cpuCards: [7, 7, -1, 9, 9, -1, 3, 3, -1, 6, 6, -1],
  ),
  86: GameLevel(
    level: 86,
    seed: 1086,
    cpu: columnAwareCpu,
    playerPointGoal: 40,
  ),
  87: GameLevel(
    level: 87,
    seed: 1087,
    cpu: columnAwareCpu,
    playerPointGoal: 40,
  ),
  88: GameLevel(
    level: 88,
    seed: 1088,
    cpu: columnAwareCpu,
    playerPointGoal: 38,
  ),
  89: GameLevel(
    level: 89,
    seed: 1089,
    cpu: columnAwareCpu,
    playerPointGoal: 36,
  ),
  90: GameLevel(
    level: 90,
    seed: 1090,
    cpu: columnAwareCpu,
    playerPointGoal: 10,
    playerCards: [12, 12, 12, 10, 10, 10, 8, 8, 8, 5, 5, 5],
  ),
  91: GameLevel(
    level: 91,
    seed: 1091,
    cpu: columnAwareCpu,
    playerPointGoal: 34,
  ),
  92: GameLevel(
    level: 92,
    seed: 1092,
    cpu: columnAwareCpu,
    playerPointGoal: 32,
  ),
  93: GameLevel(
    level: 93,
    seed: 1093,
    cpu: columnAwareCpu,
    playerPointGoal: 30,
  ),
  94: GameLevel(
    level: 94,
    seed: 1094,
    cpu: columnAwareCpu,
    playerPointGoal: 30,
  ),
  95: GameLevel(
    level: 95,
    seed: 1095,
    cpu: columnAwareCpu,
    playerPointGoal: 40,
    playerPointStartAmount: 15,
  ),
  96: GameLevel(
    level: 96,
    seed: 1096,
    cpu: columnAwareCpu,
    playerPointGoal: 28,
  ),
  97: GameLevel(
    level: 97,
    seed: 1097,
    cpu: columnAwareCpu,
    playerPointGoal: 26,
  ),
  98: GameLevel(
    level: 98,
    seed: 1098,
    cpu: columnAwareCpu,
    playerPointGoal: 25,
  ),
  99: GameLevel(
    level: 99,
    seed: 1099,
    cpu: columnAwareCpu,
    playerPointGoal: 22,
  ),
  100: GameLevel(
    level: 100,
    seed: 1100,
    cpu: columnAwareCpu,
    playerPointGoal: 20,
    cpuCards: [-2, -2, -2, 0, 0, 0, 1, 1, 1, 2, 2, 2],
  ),

  // Phase 6: Time Attack
  101: GameLevel(
    level: 101,
    seed: 1101,
    cpu: smartCpu,
    playerPointGoal: 50,
    timeout: Duration(seconds: 60),
  ),
  102: GameLevel(
    level: 102,
    seed: 1102,
    cpu: smartCpu,
    playerPointGoal: 50,
    timeout: Duration(seconds: 58),
  ),
  103: GameLevel(
    level: 103,
    seed: 1103,
    cpu: smartCpu,
    playerPointGoal: 48,
    timeout: Duration(seconds: 56),
  ),
  104: GameLevel(
    level: 104,
    seed: 1104,
    cpu: smartCpu,
    playerPointGoal: 48,
    timeout: Duration(seconds: 54),
  ),
  105: GameLevel(
    level: 105,
    seed: 1105,
    cpu: smartCpu,
    playerPointGoal: 46,
    timeout: Duration(seconds: 52),
  ),
  106: GameLevel(
    level: 106,
    seed: 1106,
    cpu: smartCpu,
    playerPointGoal: 46,
    timeout: Duration(seconds: 50),
  ),
  107: GameLevel(
    level: 107,
    seed: 1107,
    cpu: smartCpu,
    playerPointGoal: 44,
    timeout: Duration(seconds: 48),
  ),
  108: GameLevel(
    level: 108,
    seed: 1108,
    cpu: smartCpu,
    playerPointGoal: 44,
    timeout: Duration(seconds: 46),
  ),
  109: GameLevel(
    level: 109,
    seed: 1109,
    cpu: smartCpu,
    playerPointGoal: 42,
    timeout: Duration(seconds: 44),
  ),
  110: GameLevel(
    level: 110,
    seed: 1110,
    cpu: smartCpu,
    playerPointGoal: 40,
    timeout: Duration(seconds: 40),
  ),
  111: GameLevel(
    level: 111,
    seed: 1111,
    cpu: smartCpu,
    playerPointGoal: 40,
    timeout: Duration(seconds: 39),
  ),
  112: GameLevel(
    level: 112,
    seed: 1112,
    cpu: smartCpu,
    playerPointGoal: 38,
    timeout: Duration(seconds: 38),
  ),
  113: GameLevel(
    level: 113,
    seed: 1113,
    cpu: smartCpu,
    playerPointGoal: 38,
    timeout: Duration(seconds: 37),
  ),
  114: GameLevel(
    level: 114,
    seed: 1114,
    cpu: smartCpu,
    playerPointGoal: 36,
    timeout: Duration(seconds: 36),
  ),
  115: GameLevel(
    level: 115,
    seed: 1115,
    cpu: smartCpu,
    playerPointGoal: 35,
    timeout: Duration(seconds: 30),
  ),
  116: GameLevel(
    level: 116,
    seed: 1116,
    cpu: smartCpu,
    playerPointGoal: 34,
    timeout: Duration(seconds: 30),
  ),
  117: GameLevel(
    level: 117,
    seed: 1117,
    cpu: smartCpu,
    playerPointGoal: 32,
    timeout: Duration(seconds: 28),
  ),
  118: GameLevel(
    level: 118,
    seed: 1118,
    cpu: smartCpu,
    playerPointGoal: 30,
    timeout: Duration(seconds: 25),
  ),
  119: GameLevel(
    level: 119,
    seed: 1119,
    cpu: smartCpu,
    playerPointGoal: 30,
    timeout: Duration(seconds: 22),
  ),
  120: GameLevel(
    level: 120,
    seed: 1120,
    cpu: smartCpu,
    playerPointGoal: 25,
    timeout: Duration(seconds: 20),
  ),

  // Phase 7: Gimmick Gauntle
  121: GameLevel(
    level: 121,
    seed: 1121,
    cpu: simpleCpu,
    playerPointGoal: 100,
    playerPointStartAmount: 99,
  ),
  122: GameLevel(
    level: 122,
    seed: 1122,
    cpu: simpleCpu,
    playerPointGoal: 100,
    playerPointStartAmount: -99,
  ),
  123: GameLevel(level: 123, seed: 1123, cpu: simpleCpu, playerPointGoal: 40),
  124: GameLevel(level: 124, seed: 1124, cpu: simpleCpu, playerPointGoal: 35),
  125: GameLevel(
    level: 125,
    seed: 1125,
    cpu: simpleCpu,
    playerPointGoal: 50,
    playerCards: [12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12],
  ),
  126: GameLevel(level: 126, seed: 1126, cpu: simpleCpu, playerPointGoal: 40),
  127: GameLevel(level: 127, seed: 1127, cpu: gamblerCpu, playerPointGoal: 50),
  128: GameLevel(level: 128, seed: 1128, cpu: simpleCpu, playerPointGoal: 35),
  129: GameLevel(level: 129, seed: 1129, cpu: simpleCpu, playerPointGoal: 30),
  130: GameLevel(
    level: 130,
    seed: 7000,
    cpu: simpleCpu,
    playerPointGoal: 100,
    playerCards: [1, 5, 12, -2, 8, 3, 7, 7, 0, 9, 10, 4],
    cpuCards: [1, 5, 12, -2, 8, 3, 7, 7, 0, 9, 10, 4],
  ),
  131: GameLevel(level: 131, seed: 1131, cpu: veryEasyCpu, playerPointGoal: 20),
  132: GameLevel(level: 132, seed: 1132, cpu: simpleCpu, playerPointGoal: 30),
  133: GameLevel(level: 133, seed: 1133, cpu: simpleCpu, playerPointGoal: 25),
  134: GameLevel(level: 134, seed: 1134, cpu: simpleCpu, playerPointGoal: 25),
  135: GameLevel(
    level: 135,
    seed: 1135,
    playerPointGoal: 50,
    cpuCards: [12, 12, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8],
    cpu: RevealCPU(
      player: cpuPlayer,
      initialFlipStrategy: fixedFlipStrategy(Point(0, 2), Point(0, 3)),
      discardStrategy: simpleCpu.discardStrategy,
      swapOrFlipStrategy: simpleCpu.swapOrFlipStrategy,
    ),
  ),
  136: GameLevel(level: 136, seed: 1136, cpu: simpleCpu, playerPointGoal: 30),
  137: GameLevel(level: 137, seed: 1137, cpu: smartCpu, playerPointGoal: 30),
  138: GameLevel(level: 138, seed: 1138, cpu: simpleCpu, playerPointGoal: 20),
  139: GameLevel(level: 139, seed: 1139, cpu: simpleCpu, playerPointGoal: 20),
  140: GameLevel(
    level: 140,
    seed: 1140,
    cpu: simpleCpu,
    playerPointGoal: 100,
    playerCards: [12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12],
    cpuCards: [12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12],
  ),

  // Phase 8: The "Perfect" A
  // Goal: The ultimate, ruthless AI opponent
  141: GameLevel(level: 141, seed: 1141, cpu: perfectCpu, playerPointGoal: 30),
  142: GameLevel(level: 142, seed: 1142, cpu: perfectCpu, playerPointGoal: 28),
  143: GameLevel(level: 143, seed: 1143, cpu: perfectCpu, playerPointGoal: 26),
  144: GameLevel(level: 144, seed: 1144, cpu: perfectCpu, playerPointGoal: 25),
  145: GameLevel(level: 145, seed: 1145, cpu: perfectCpu, playerPointGoal: 24),
  146: GameLevel(level: 146, seed: 1146, cpu: perfectCpu, playerPointGoal: 22),
  147: GameLevel(level: 147, seed: 1147, cpu: perfectCpu, playerPointGoal: 20),
  148: GameLevel(level: 148, seed: 1148, cpu: perfectCpu, playerPointGoal: 20),
  149: GameLevel(level: 149, seed: 1149, cpu: perfectCpu, playerPointGoal: 18),
  150: GameLevel(level: 150, seed: 1150, cpu: perfectCpu, playerPointGoal: 15),
  151: GameLevel(level: 151, seed: 1151, cpu: perfectCpu, playerPointGoal: 15),
  152: GameLevel(level: 152, seed: 1152, cpu: perfectCpu, playerPointGoal: 14),
  153: GameLevel(level: 153, seed: 1153, cpu: perfectCpu, playerPointGoal: 12),
  154: GameLevel(level: 154, seed: 1154, cpu: perfectCpu, playerPointGoal: 12),
  155: GameLevel(
    level: 155,
    seed: 1155,
    cpu: perfectCpu,
    playerPointGoal: 20,
    playerPointStartAmount: 10,
  ),
  156: GameLevel(level: 156, seed: 1156, cpu: perfectCpu, playerPointGoal: 10),
  157: GameLevel(level: 157, seed: 1157, cpu: perfectCpu, playerPointGoal: 8),
  158: GameLevel(level: 158, seed: 1158, cpu: perfectCpu, playerPointGoal: 6),
  159: GameLevel(level: 159, seed: 1159, cpu: perfectCpu, playerPointGoal: 5),
  160: GameLevel(level: 160, seed: 1160, cpu: perfectCpu, playerPointGoal: 0),
  // Phase 9: Handicap Level
  // Goal: Win with a smaller score buffer than the CPU vs. Smart AI
  // Logic: playerPointGoal - playerPointStartAmount = Player's "Health"
  161: GameLevel(
    level: 161,
    seed: 1161,
    cpu: smartCpu,
    playerPointGoal: 100,
    playerPointStartAmount: 20,
  ),
  162: GameLevel(
    level: 162,
    seed: 1162,
    cpu: smartCpu,
    playerPointGoal: 100,
    playerPointStartAmount: 30,
  ),
  163: GameLevel(
    level: 163,
    seed: 1163,
    cpu: smartCpu,
    playerPointGoal: 100,
    playerPointStartAmount: 40,
  ),
  164: GameLevel(
    level: 164,
    seed: 1164,
    cpu: smartCpu,
    playerPointGoal: 100,
    playerPointStartAmount: 50,
  ),
  165: GameLevel(
    level: 165,
    seed: 1165,
    cpu: smartCpu,
    playerPointGoal: 80,
    playerPointStartAmount: 40,
  ),
  166: GameLevel(
    level: 166,
    seed: 1166,
    cpu: smartCpu,
    playerPointGoal: 70,
    playerPointStartAmount: 40,
  ),
  167: GameLevel(
    level: 167,
    seed: 1167,
    cpu: smartCpu,
    playerPointGoal: 60,
    playerPointStartAmount: 35,
  ),
  168: GameLevel(
    level: 168,
    seed: 1168,
    cpu: smartCpu,
    playerPointGoal: 50,
    playerPointStartAmount: 30,
  ),
  169: GameLevel(
    level: 169,
    seed: 1169,
    cpu: smartCpu,
    playerPointGoal: 40,
    playerPointStartAmount: 25,
  ),
  170: GameLevel(
    level: 170,
    seed: 1170,
    cpu: smartCpu,
    playerPointGoal: 30,
    playerPointStartAmount: 15,
  ),
  171: GameLevel(
    level: 171,
    seed: 1171,
    cpu: smartCpu,
    playerPointGoal: 30,
    playerPointStartAmount: 20,
  ),
  172: GameLevel(
    level: 172,
    seed: 1172,
    cpu: smartCpu,
    playerPointGoal: 20,
    playerPointStartAmount: 10,
  ),
  173: GameLevel(
    level: 173,
    seed: 1173,
    cpu: smartCpu,
    playerPointGoal: 15,
    playerPointStartAmount: 5,
  ),
  174: GameLevel(
    level: 174,
    seed: 1174,
    cpu: smartCpu,
    playerPointGoal: 10,
    playerPointStartAmount: 0,
  ),
  175: GameLevel(
    level: 175,
    seed: 1175,
    cpu: smartCpu,
    playerPointGoal: 50,
    playerPointStartAmount: 45,
  ),
  176: GameLevel(
    level: 176,
    seed: 1176,
    cpu: smartCpu,
    playerPointGoal: 40,
    playerPointStartAmount: 35,
    timeout: Duration(seconds: 45),
  ),
  177: GameLevel(
    level: 177,
    seed: 1177,
    cpu: smartCpu,
    playerPointGoal: 30,
    playerPointStartAmount: 25,
  ),
  178: GameLevel(
    level: 178,
    seed: 1178,
    cpu: smartCpu,
    playerPointGoal: 20,
    playerPointStartAmount: 15,
  ),
  179: GameLevel(
    level: 179,
    seed: 1179,
    cpu: smartCpu,
    playerPointGoal: 10,
    playerPointStartAmount: 5,
    timeout: Duration(seconds: 40),
  ),
  180: GameLevel(
    level: 180,
    seed: 1180,
    cpu: smartCpu,
    playerPointGoal: 5,
    playerPointStartAmount: 0,
  ),

  // Phase 10: Grand Final
  181: GameLevel(
    level: 181,
    seed: 1181,
    cpu: perfectCpu,
    playerPointGoal: 30,
    cpuPointGoal: 30,
  ),
  182: GameLevel(
    level: 182,
    seed: 1182,
    cpu: perfectCpu,
    playerPointGoal: 25,
    cpuPointGoal: 25,
  ),
  183: GameLevel(
    level: 183,
    seed: 1183,
    cpu: perfectCpu,
    playerPointGoal: 20,
    cpuPointGoal: 20,
  ),
  184: GameLevel(
    level: 184,
    seed: 1184,
    cpu: perfectCpu,
    playerPointGoal: 10,
    cpuPointGoal: 10,
  ),
  185: GameLevel(
    level: 185,
    seed: 1185,
    cpu: perfectCpu,
    playerPointGoal: 30,
    cpuPointGoal: 30,
    timeout: Duration(seconds: 30),
  ),
  186: GameLevel(
    level: 186,
    seed: 1186,
    cpu: perfectCpu,
    playerPointGoal: 25,
    cpuPointGoal: 25,
    timeout: Duration(seconds: 25),
  ),
  187: GameLevel(
    level: 187,
    seed: 1187,
    cpu: perfectCpu,
    playerPointGoal: 20,
    cpuPointGoal: 20,
    timeout: Duration(seconds: 20),
  ),
  188: GameLevel(
    level: 188,
    seed: 1188,
    cpu: perfectCpu,
    playerPointGoal: 50,
    playerPointStartAmount: 30,
    cpuPointGoal: 50,
  ),
  189: GameLevel(
    level: 189,
    seed: 1189,
    cpu: perfectCpu,
    playerPointGoal: 40,
    playerPointStartAmount: 30,
    cpuPointGoal: 40,
  ),
  190: GameLevel(
    level: 190,
    seed: 1190,
    cpu: perfectCpu,
    playerPointGoal: 30,
    playerPointStartAmount: 25,
    cpuPointGoal: 30,
  ),
  191: GameLevel(
    level: 191,
    seed: 1191,
    cpu: perfectCpu,
    playerPointGoal: 100,
    cpuPointGoal: 100,
    cpuPointStartAmount: -20,
  ),
  192: GameLevel(
    level: 192,
    seed: 1192,
    cpu: perfectCpu,
    playerPointGoal: 100,
    cpuPointGoal: 100,
    cpuPointStartAmount: -10,
    cpuCards: [-2, -2, -1, -1, 0, 0, 1, 1, 2, 2, 3, 3],
  ),
  193: GameLevel(
    level: 193,
    seed: 1193,
    cpu: perfectCpu,
    playerPointGoal: 100,
    cpuPointGoal: 100,
    cpuPointStartAmount: -25,
  ),
  194: GameLevel(
    level: 194,
    seed: 1194,
    cpu: perfectCpu,
    playerPointGoal: 100,
    cpuPointGoal: 100,
    playerCards: [12, 12, 12, 10, 10, 10, 8, 8, 8, 7, 7, 7],
  ),
  195: GameLevel(
    level: 195,
    seed: 1195,
    cpu: perfectCpu,
    playerPointGoal: 30,
    cpuPointGoal: 100,
    playerCards: [12, 12, 12, 12, 12, 12, 5, 5, 5, 0, 0, 0],
  ),
  196: GameLevel(
    level: 196,
    seed: 1196,
    cpu: perfectCpu,
    playerPointGoal: 50,
    playerPointStartAmount: 20,
    cpuPointGoal: 100,
    timeout: Duration(seconds: 40),
  ),
  197: GameLevel(
    level: 197,
    seed: 1197,
    cpu: perfectCpu,
    playerPointGoal: 40,
    playerPointStartAmount: 25,
    cpuPointGoal: 100,
    timeout: Duration(seconds: 35),
  ),
  198: GameLevel(
    level: 198,
    seed: 1198,
    cpu: perfectCpu,
    playerPointGoal: 30,
    playerPointStartAmount: 20,
    cpuPointGoal: 100,
    timeout: Duration(seconds: 30),
  ),
  199: GameLevel(
    level: 199,
    seed: 1199,
    cpu: perfectCpu,
    playerPointGoal: 50,
    playerPointStartAmount: 30,
    cpuPointGoal: 100,
    cpuPointStartAmount: -15,
    timeout: Duration(seconds: 30),
    cpuCards: [-2, -2, -1, -1, 0, 0, 1, 1, 2, 2, 3, 3],
  ),
  200: GameLevel(
    level: 200,
    seed: 2000,
    cpu: perfectCpu,
    playerPointGoal: 20,
    playerPointStartAmount: 15,
    cpuPointGoal: 100,
    cpuPointStartAmount: -24,
    timeout: Duration(seconds: 25),
    cpuCards: [-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2],
  ),
};
