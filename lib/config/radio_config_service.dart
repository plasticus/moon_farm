// ═══════════════════════════════════════════════════════════════
//  lib/config/radio_config_service.dart
// ═══════════════════════════════════════════════════════════════
// Loads the two radio TOML files and exposes them as plain Dart
// structures for the engine/UI to consume.
//   - radio_pool.toml      -> random flavor-text messages
//   - radio_triggers.toml  -> one-shot, condition-based messages
//
// See radio_triggers.toml itself for the full list of supported
// trigger kinds and how to add new entries — this file is just
// plumbing, the actual content lives in the TOML.

import 'package:flutter/services.dart';
import 'package:toml/toml.dart';

class RadioConfigService {
  RadioConfigService._();
  static final RadioConfigService instance = RadioConfigService._();

  List<String> _pool = [];
  List<Map<String, dynamic>> _triggers = [];

  bool get isLoaded => _pool.isNotEmpty || _triggers.isNotEmpty;

  Future<void> load() async {
    _pool = await _loadPool('assets/config/radio_pool.toml');
    _triggers = await _loadTriggers('assets/config/radio_triggers.toml');
  }

  Future<List<String>> _loadPool(String path) async {
    final raw = await rootBundle.loadString(path);
    final doc = TomlDocument.parse(raw).toMap();
    final messages = doc['message'] as List? ?? [];
    return messages
        .map((m) => (m as Map)['text'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadTriggers(String path) async {
    final raw = await rootBundle.loadString(path);
    final doc = TomlDocument.parse(raw).toMap();
    final triggers = doc['trigger'] as List? ?? [];
    return triggers.map((t) => Map<String, dynamic>.from(t as Map)).toList();
  }

  /// The random flavor-text pool (radio_pool.toml).
  List<String> get pool => _pool;

  /// All trigger definitions (radio_triggers.toml), in file order.
  List<Map<String, dynamic>> get triggers => _triggers;

  /// Week-keyed tips flagged `show_as_tip = true`, in the same
  /// {week, message} shape the old JSON-backed getRadioTips() used —
  /// lets the Week Summary / Habitat "current tip" banner keep working
  /// unchanged while the underlying data now lives in TOML.
  List<Map<String, dynamic>> get tipBannerEntries => _triggers
      .where((t) => t['kind'] == 'week' && t['show_as_tip'] == true)
      .map((t) => {'week': t['value'], 'message': t['message']})
      .toList();
}
