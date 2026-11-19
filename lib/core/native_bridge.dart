import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../models/device_status.dart';
import '../models/game.dart';

/// Pont Flutter <-> Android (code Kotlin dans MainActivity.kt).
///
/// Toutes les méthodes sont « sûres » : sur iOS, ou en cas d'erreur, elles
/// renvoient une valeur par défaut au lieu de faire planter l'appli.
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('gamelauncher/native');

  /// Liste des jeux, nettoyage RAM, « Ne pas déranger » : Android uniquement.
  /// iOS interdit à une appli de voir les autres applis ou de les fermer.
  static bool get supported => Platform.isAndroid;

  // Jeux fictifs affichés quand on n'est pas sur Android (démo / tests).
  static const List<Game> _demoGames = <Game>[
    Game(name: 'Asphalt Nitro', packageName: 'demo.asphalt'),
    Game(name: 'Drift Legends', packageName: 'demo.drift'),
    Game(name: 'Neon Racer', packageName: 'demo.neon'),
    Game(name: 'Turbo Garage', packageName: 'demo.turbo'),
    Game(name: 'Apex Pursuit', packageName: 'demo.apex'),
    Game(name: 'Rally Storm', packageName: 'demo.rally'),
  ];

  /// Jeux installés (ou toutes les applis lançables si [includeAll]).
  static Future<List<Game>> getGames({bool includeAll = false}) async {
    if (!supported) return _demoGames;
    try {
      final List<dynamic>? raw = await _channel
          .invokeMethod<List<dynamic>>('getGames', <String, dynamic>{'includeAll': includeAll});
      final List<Game> games = <Game>[];
      for (final dynamic item in raw ?? const <dynamic>[]) {
        if (item is! Map) continue;
        games.add(Game(
          name: (item['name'] as String?) ?? '?',
          packageName: (item['package'] as String?) ?? '',
          icon: item['icon'] as Uint8List?,
          isGame: (item['isGame'] as bool?) ?? true,
        ));
      }
      return games;
    } on PlatformException catch (e) {
      debugPrint('getGames a échoué : $e');
    } on MissingPluginException {
      debugPrint('getGames : code natif absent (MainActivity.kt copié ?)');
    }
    return const <Game>[];
  }

  /// Lance le jeu. Renvoie false s'il est introuvable ou en mode démo.
  static Future<bool> launchGame(String packageName) async {
    if (!supported) return false;
    try {
      final bool? ok = await _channel
          .invokeMethod<bool>('launchGame', <String, dynamic>{'package': packageName});
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('launchGame a échoué : $e');
    } on MissingPluginException {
      debugPrint('launchGame : code natif absent');
    }
    return false;
  }

  static Future<BatteryStatus> getBattery() async {
    if (!supported) return BatteryStatus.unknown;
    try {
      final Map<String, dynamic>? m =
          await _channel.invokeMapMethod<String, dynamic>('getBattery');
      if (m == null) return BatteryStatus.unknown;
      return BatteryStatus(
        level: (m['level'] as num?)?.toInt() ?? -1,
        tempC: (m['tempC'] as num?)?.toDouble() ?? 0,
        charging: (m['charging'] as bool?) ?? false,
        thermal: (m['thermal'] as num?)?.toInt() ?? -1,
      );
    } on PlatformException catch (e) {
      debugPrint('getBattery a échoué : $e');
    } on MissingPluginException {
      debugPrint('getBattery : code natif absent');
    }
    return BatteryStatus.unknown;
  }

  static Future<MemoryStatus?> getMemory() async {
    if (!supported) return null;
    try {
      final Map<String, dynamic>? m =
          await _channel.invokeMapMethod<String, dynamic>('getMemory');
      if (m == null) return null;
      return MemoryStatus(
        availMb: (m['availMb'] as num?)?.toInt() ?? 0,
        totalMb: (m['totalMb'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException catch (e) {
      debugPrint('getMemory a échoué : $e');
    } on MissingPluginException {
      debugPrint('getMemory : code natif absent');
    }
    return null;
  }

  /// Demande à Android de fermer les processus en arrière-plan des applis
  /// (hors système et hors appli au premier plan). Dure environ 1 seconde.
  static Future<CleanResult?> cleanRam({String? keepPackage}) async {
    if (!supported) return null;
    try {
      final Map<String, dynamic>? m =
          await _channel.invokeMapMethod<String, dynamic>(
              'cleanRam', <String, dynamic>{'keep': keepPackage});
      if (m == null) return null;
      return CleanResult(
        availBeforeMb: (m['availBeforeMb'] as num?)?.toInt() ?? 0,
        availAfterMb: (m['availAfterMb'] as num?)?.toInt() ?? 0,
        totalMb: (m['totalMb'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException catch (e) {
      debugPrint('cleanRam a échoué : $e');
    } on MissingPluginException {
      debugPrint('cleanRam : code natif absent');
    }
    return null;
  }

  static Future<DndStatus> dndStatus() async {
    const DndStatus none = DndStatus(granted: false, active: false);
    if (!supported) return none;
    try {
      final Map<String, dynamic>? m =
          await _channel.invokeMapMethod<String, dynamic>('dndStatus');
      if (m == null) return none;
      return DndStatus(
        granted: (m['granted'] as bool?) ?? false,
        active: (m['active'] as bool?) ?? false,
      );
    } on PlatformException catch (e) {
      debugPrint('dndStatus a échoué : $e');
    } on MissingPluginException {
      debugPrint('dndStatus : code natif absent');
    }
    return none;
  }

  /// Ouvre l'écran Android où l'utilisateur autorise l'accès à « Ne pas déranger ».
  static Future<void> openDndSettings() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('openDndSettings');
    } on PlatformException catch (e) {
      debugPrint('openDndSettings a échoué : $e');
    } on MissingPluginException {
      debugPrint('openDndSettings : code natif absent');
    }
  }

  /// Active / désactive « Ne pas déranger ». Faux si l'accès n'est pas accordé.
  static Future<bool> setDnd(bool enabled) async {
    if (!supported) return false;
    try {
      final bool? ok = await _channel
          .invokeMethod<bool>('setDnd', <String, dynamic>{'enabled': enabled});
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('setDnd a échoué : $e');
    } on MissingPluginException {
      debugPrint('setDnd : code natif absent');
    }
    return false;
  }
}
