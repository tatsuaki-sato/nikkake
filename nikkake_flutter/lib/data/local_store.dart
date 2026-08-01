import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末ローカルの永続化レイヤ。
///
/// SharedPreferences をJSON文字列のバケツとして使う。
/// 画面描画のたびにデコードすると重いので、読み込んだコレクションは
/// メモリにキャッシュし、書き込み時に両方を更新する。
class LocalStore {
  static const prefix = 'nikkake:v1:';

  final SharedPreferences _prefs;
  final _cache = <String, dynamic>{};

  LocalStore(this._prefs);

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  String _key(String name) => '$prefix$name';

  List<Map<String, dynamic>> readCollection(String name) {
    final key = _key(name);
    final cached = _cache[key];
    if (cached != null) return cached as List<Map<String, dynamic>>;

    final raw = _prefs.getString(key);
    if (raw == null) {
      final empty = <Map<String, dynamic>>[];
      _cache[key] = empty;
      return empty;
    }

    try {
      final decoded = jsonDecode(raw);
      final rows = decoded is List
          ? decoded.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      _cache[key] = rows;
      return rows;
    } catch (_) {
      // 壊れたJSONで起動不能になるのが最悪なので、握りつぶして空で復旧する
      final empty = <Map<String, dynamic>>[];
      _cache[key] = empty;
      return empty;
    }
  }

  Future<void> writeCollection(String name, List<Map<String, dynamic>> rows) async {
    final key = _key(name);
    _cache[key] = rows;
    await _prefs.setString(key, jsonEncode(rows));
  }

  Map<String, dynamic> readObject(String name, Map<String, dynamic> fallback) {
    final key = _key(name);
    final cached = _cache[key];
    if (cached != null) return cached as Map<String, dynamic>;

    final raw = _prefs.getString(key);
    if (raw == null) {
      _cache[key] = fallback;
      return fallback;
    }

    try {
      final value = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _cache[key] = value;
      return value;
    } catch (_) {
      _cache[key] = fallback;
      return fallback;
    }
  }

  Future<void> writeObject(String name, Map<String, dynamic> value) async {
    final key = _key(name);
    _cache[key] = value;
    await _prefs.setString(key, jsonEncode(value));
  }

  /// テストとデータ初期化用
  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    _cache.clear();
  }
}
