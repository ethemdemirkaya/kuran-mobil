import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'models.dart';

enum AudioMode {
  arabic('Arapça'),
  meal('Meal'),
  both('Arapça + Meal');

  const AudioMode(this.label);
  final String label;
}

class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  double get arabicSize => _prefs.getDouble('arabicSize') ?? 30;
  set arabicSize(double v) => _set(() => _prefs.setDouble('arabicSize', v));

  double get mealSize => _prefs.getDouble('mealSize') ?? 19;
  set mealSize(double v) => _set(() => _prefs.setDouble('mealSize', v));

  bool get showMeal => _prefs.getBool('showMeal') ?? true;
  set showMeal(bool v) => _set(() => _prefs.setBool('showMeal', v));

  AudioMode get audioMode =>
      AudioMode.values[_prefs.getInt('audioMode') ?? AudioMode.arabic.index];
  set audioMode(AudioMode v) => _set(() => _prefs.setInt('audioMode', v.index));

  double get speed => _prefs.getDouble('speed') ?? 1.0;
  set speed(double v) => _set(() => _prefs.setDouble('speed', v));

  bool get autoNext => _prefs.getBool('autoNext') ?? true;
  set autoNext(bool v) => _set(() => _prefs.setBool('autoNext', v));

  /// Okunan kelimeyi boya.
  bool get wordHighlight => _prefs.getBool('wordHighlight') ?? true;
  set wordHighlight(bool v) => _set(() => _prefs.setBool('wordHighlight', v));

  /// Arapça okuyan hafız ([AppConfig.reciters] kimliği).
  int get arabicReciter => _prefs.getInt('arabicReciter') ?? 0;
  set arabicReciter(int id) => _set(() => _prefs.setInt('arabicReciter', id));
  Reciter get reciter => AppConfig.reciter(arabicReciter);

  /// Gösterilen meal ([AppConfig.meals] kimliği).
  String get mealSource => _prefs.getString('mealSource') ?? 'diyanet';
  set mealSource(String v) => _set(() => _prefs.setString('mealSource', v));
  MealSource get meal => AppConfig.meal(mealSource);

  bool get keepScreenOn => _prefs.getBool('keepScreenOn') ?? true;
  set keepScreenOn(bool v) => _set(() => _prefs.setBool('keepScreenOn', v));

  ThemeMode get themeMode =>
      ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.light.index];
  set themeMode(ThemeMode v) => _set(() => _prefs.setInt('themeMode', v.index));

  /// Son okunan yer (sure, ayet).
  (int, int)? get lastRead {
    final s = _prefs.getInt('lastSurah');
    final v = _prefs.getInt('lastVerse');
    return s == null || v == null ? null : (s, v);
  }

  void setLastRead(int surah, int verse) {
    if (lastRead == (surah, verse)) return;
    _set(() => Future.wait([
          _prefs.setInt('lastSurah', surah),
          _prefs.setInt('lastVerse', verse),
        ]));
  }

  List<Bookmark> get bookmarks {
    final raw = _prefs.getString('bookmarks');
    if (raw == null) return const [];
    return [
      for (final j in jsonDecode(raw) as List)
        Bookmark.fromJson(j as Map<String, dynamic>),
    ];
  }

  bool isBookmarked(int surah, int verse) =>
      bookmarks.any((b) => b.surah == surah && b.verse == verse);

  void toggleBookmark(Verse v) {
    final list = bookmarks.toList();
    final i = list.indexWhere((b) => b.surah == v.surah && b.verse == v.number);
    if (i >= 0) {
      list.removeAt(i);
    } else {
      final snippet = v.meal.length > 120 ? '${v.meal.substring(0, 120)}…' : v.meal;
      list.insert(0, Bookmark(v.surah, v.number, snippet));
    }
    _set(() => _prefs.setString(
        'bookmarks', jsonEncode([for (final b in list) b.toJson()])));
  }

  void removeBookmark(Bookmark b) {
    final list = bookmarks.where((x) => x.key != b.key).toList();
    _set(() => _prefs.setString(
        'bookmarks', jsonEncode([for (final b in list) b.toJson()])));
  }

  void _set(Future<Object?> Function() write) {
    write();
    notifyListeners();
  }
}
