// ═══════════════════════════════════════════════════════════════
//  lib/config/kovacs_config_service.dart
// ═══════════════════════════════════════════════════════════════
// Loads Kovacs dialogue from assets/config/kovacs_dialog.json.
// Edit that file to change any dialogue — no Dart changes needed.

import 'dart:convert';
import 'package:flutter/services.dart';

class KovacsConfigService {
  KovacsConfigService._();
  static final KovacsConfigService instance = KovacsConfigService._();

  Map<String, dynamic>? _data;

  bool get isLoaded => _data != null;

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config/kovacs_dialog.json');
    _data = json.decode(raw) as Map<String, dynamic>;
  }

  // ─── Greetings ────────────────────────────────────────────────

  /// Returns greeting lines for the given mood tier key
  /// (hostile / sour / neutral / happy / elated).
  List<String> greetingsForMood(String moodKey) {
    final greetings = _data?['greetings'] as Map<String, dynamic>?;
    final list = greetings?[moodKey] as List?;
    return list?.map((e) => e.toString()).toList() ?? [];
  }

  // ─── Topics ───────────────────────────────────────────────────

  List<Map<String, dynamic>> get allTopics {
    final list = _data?['topics'] as List?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  List<Map<String, dynamic>> get tier1Topics =>
      allTopics.where((t) => t['tier'] == 1).toList();

  List<Map<String, dynamic>> get tier2Topics =>
      allTopics.where((t) => t['tier'] == 2).toList();

  Map<String, dynamic>? topicById(String id) {
    for (final t in allTopics) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  List<String> responsesForTopic(String id) {
    final topic = topicById(id);
    final pool = topic?['response_pool'] as List?;
    return pool?.map((e) => e.toString()).toList() ?? [];
  }

  int moodChangeForTopic(String id) =>
      topicById(id)?['mood_change'] as int? ?? 0;

  String? moodHintForTopic(String id) =>
      topicById(id)?['mood_hint'] as String?;

  List<String> unlocksForTopic(String id) {
    final topic = topicById(id);
    final unlocks = topic?['unlocks'] as List?;
    return unlocks?.map((e) => e.toString()).toList() ?? [];
  }

  // ─── Idle transmissions ───────────────────────────────────────

  List<String> get idleTransmissions {
    final list = _data?['idle_transmissions'] as List?;
    return list?.map((e) => e.toString()).toList() ?? [];
  }
}