import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import 'models.dart';
import 'words.dart';

/// Sure ve ayet verisi. Önce Diyanet API'sini kullanır; anahtarın erişimi
/// dışında kalan ayetleri yedek kaynaktan tamamlar. Tamamlanan sureler
/// cihazda saklanır, ikinci açılışta internet gerekmez.
class QuranRepository {
  final _client = http.Client();
  final _memory = <int, List<Verse>>{};
  List<Surah>? _surahs;
  List<Verse>? _juz1;
  final _precise = <String, PreciseSurah>{};
  final _altMeals = <String, Map<int, String>>{};
  final _archive = <int, Map<String, dynamic>>{};
  final _archiveSurahs = <String, PreciseSurah>{};
  Directory? _cacheDir;

  static const _cacheVersion = 1;

  Future<List<Surah>> surahs() async {
    if (_surahs != null) return _surahs!;
    final raw = await rootBundle.loadString('assets/data/chapters.json');
    final data = (jsonDecode(raw) as Map<String, dynamic>)['data'] as List;
    return _surahs = [
      for (final j in data) Surah.fromDiyanet(j as Map<String, dynamic>),
    ];
  }

  Future<Surah> surah(int id) async => (await surahs())[id - 1];

  Future<List<Verse>> verses(int surahId) async {
    final cached = _memory[surahId] ?? await _readCache(surahId);
    if (cached != null) return _memory[surahId] = cached;

    final surah = await this.surah(surahId);
    final byNumber = <int, Verse>{};

    if (AppConfig.diyanetToken.isNotEmpty) {
      try {
        for (final v in await _diyanetChapter(surahId)) {
          byNumber[v.number] = v;
        }
        if (surah.juz == 1 && byNumber.length < surah.verseCount) {
          for (final v in await _diyanetJuz1()) {
            if (v.surah == surahId) byNumber[v.number] = v;
          }
        }
      } catch (_) {
        // Yedek kaynağa düşülür.
      }
    }

    if (byNumber.length < surah.verseCount) {
      try {
        for (final v in await _fallbackChapter(surahId)) {
          byNumber.putIfAbsent(v.number, () => v);
        }
      } catch (_) {
        if (byNumber.isEmpty) rethrow;
      }
    }

    final list = byNumber.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    if (list.length >= surah.verseCount) await _writeCache(surahId, list);
    return _memory[surahId] = list;
  }

  /// Tam kelime takibi için Quran.com verisi (hafıza göre).
  Future<PreciseSurah> precise(int surahId, int reciterId) async {
    final key = '$reciterId:$surahId';
    final hit = _precise[key];
    if (hit != null) return hit;

    final timingBody = await _cachedGet(
      'timing_${reciterId}_$surahId.json',
      '${AppConfig.preciseBase}/$reciterId/audio_files?chapter=$surahId&segments=true',
    );
    final textBody = await _cachedGet(
      'words_$surahId.json',
      '${AppConfig.preciseTextBase}?chapter_number=$surahId',
    );

    final file = ((jsonDecode(timingBody) as Map)['audio_files'] as List).first as Map;
    final timings = <int, VerseTiming>{};
    for (final t in file['verse_timings'] as List) {
      final verse = int.parse((t['verse_key'] as String).split(':')[1]);
      final from = (t['timestamp_from'] as num).toInt();
      timings[verse] = VerseTiming(from, (t['timestamp_to'] as num).toInt(), [
        for (final seg in (t['segments'] as List? ?? const []))
          if (seg is List && seg.length == 3)
            WordTiming(
              (seg[0] as num).toInt() - 1,
              (seg[1] as num).toInt() - from,
              (seg[2] as num).toInt() - from,
            ),
      ]);
    }

    final words = <int, List<String>>{
      for (final v in (jsonDecode(textBody) as Map)['verses'] as List)
        int.parse((v['verse_key'] as String).split(':')[1]):
            arabicTokens(v['text_uthmani'] as String),
    };
    return _precise[key] = PreciseSurah(file['audio_url'] as String, timings, words);
  }

  /// archive.org hafızı için ayet sınırları (uygulamayla gelir).
  /// Kelime takibi olan hafız için sure verisi (Quran.com ya da archive.org).
  Future<PreciseSurah> wordSync(Reciter reciter, int surahId) => reciter.precise
      ? precise(surahId, reciter.id)
      : archive(reciter, surahId);

  /// archive.org hafızı: sure sesi + uygulamayla gelen ayet/kelime hizalaması.
  ///
  /// Hizalama, üç Quran.com hafızının bilinen kelime zamanlarına sesin sesle
  /// eşlenmesiyle (DTW) üretildi; kelime sırası Quran.com metnine göredir.
  /// Ayet 0 = sure başındaki istiaze/besmele.
  Future<PreciseSurah> archive(Reciter reciter, int surahId) async {
    final key = '${reciter.id}:$surahId';
    final hit = _archiveSurahs[key];
    if (hit != null) return hit;
    final all = _archive[reciter.id] ??=
        jsonDecode(await rootBundle.loadString(reciter.timingsAsset)) as Map<String, dynamic>;
    final rec = all['$surahId'] as Map<String, dynamic>?;
    if (rec == null) throw StateError('$surahId için hizalama yok');

    final timings = <int, VerseTiming>{};
    final besmele = rec['b'] as List?;
    if (besmele != null) {
      timings[0] = VerseTiming(besmele[0] as int, besmele[1] as int, const []);
    }
    for (final (i, v) in (rec['v'] as List).indexed) {
      final from = (v as List)[0] as int;
      final to = v[1] as int;
      final offs = (v[2] as List).cast<int>();
      timings[i + 1] = VerseTiming(from, to, [
        for (var w = 0; w < offs.length; w++)
          WordTiming(w, offs[w], w + 1 < offs.length ? offs[w + 1] : to - from),
      ]);
    }
    final textBody = await _cachedGet(
      'words_$surahId.json',
      '${AppConfig.preciseTextBase}?chapter_number=$surahId',
    );
    final words = <int, List<String>>{
      for (final v in (jsonDecode(textBody) as Map)['verses'] as List)
        int.parse((v['verse_key'] as String).split(':')[1]):
            arabicTokens(v['text_uthmani'] as String),
    };
    return _archiveSurahs[key] = PreciseSurah(reciter.surahUrl(surahId), timings, words);
  }

  /// Diyanet dışındaki bir meal (alquran.cloud baskısı), ayet numarasına göre.
  Future<Map<int, String>> altMeal(int surahId, String edition) async {
    final key = '$edition:$surahId';
    final hit = _altMeals[key];
    if (hit != null) return hit;
    final body = await _cachedGet(
      'meal_${edition}_$surahId.json',
      '${AppConfig.fallbackBase}/surah/$surahId/$edition',
    );
    final ayahs = ((jsonDecode(body) as Map)['data'] as Map)['ayahs'] as List;
    return _altMeals[key] = {
      for (final a in ayahs)
        a['numberInSurah'] as int: (a['text'] as String).trim(),
    };
  }

  /// Önbellekte varsa oradan, yoksa indirip önbelleğe yazar.
  Future<String> _cachedGet(String name, String url) async {
    _cacheDir ??= await getApplicationSupportDirectory();
    final f = File('${_cacheDir!.path}/$name');
    if (await f.exists()) return f.readAsString();
    final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw HttpException('Quran.com ${res.statusCode}');
    final body = utf8.decode(res.bodyBytes);
    await f.writeAsString(body);
    return body;
  }

  // ---- Diyanet ----

  Future<List<Verse>> _diyanetChapter(int id) async =>
      _parseDiyanet(await _diyanetGet('chapters/$id'));

  Future<List<Verse>> _diyanetJuz1() async =>
      _juz1 ??= _parseDiyanet(await _diyanetGet('juz/1'));

  List<Verse> _parseDiyanet(Map<String, dynamic> body) => [
        for (final j in body['data'] as List)
          Verse(
            surah: j['surah_id'] as int,
            number: j['verse_id_in_surah'] as int,
            arabic: (j['arabic_script']['text'] as String).trim(),
            meal: (j['translation']['text'] as String).trim(),
            page: j['page_number'] as int,
          ),
      ];

  Future<Map<String, dynamic>> _diyanetGet(String path) async {
    // Sunucu zaman zaman bağlantıyı kesiyor; birkaç kez dene.
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _client.get(
          Uri.parse('${AppConfig.diyanetBase}/$path'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.diyanetToken}',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        }
        throw HttpException('Diyanet API ${res.statusCode}');
      } catch (e) {
        lastError = e;
        if (e is HttpException) break;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError!;
  }

  // ---- Yedek kaynak ----

  Future<List<Verse>> _fallbackChapter(int id) async {
    final res = await _client
        .get(Uri.parse(
            '${AppConfig.fallbackBase}/surah/$id/editions/quran-uthmani,tr.diyanet'))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw HttpException('Yedek kaynak ${res.statusCode}');
    }
    final editions =
        (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['data']
            as List;
    final arabic = editions[0]['ayahs'] as List;
    final meal = editions[1]['ayahs'] as List;
    return [
      for (var i = 0; i < arabic.length; i++)
        Verse(
          surah: id,
          number: arabic[i]['numberInSurah'] as int,
          arabic: _stripBesmele(id, i, arabic[i]['text'] as String),
          meal: (meal[i]['text'] as String).trim(),
          page: arabic[i]['page'] as int,
        ),
    ];
  }

  /// Bu kaynakta ilk ayetin başına besmele eklenmiş geliyor.
  String _stripBesmele(int surah, int index, String text) {
    text = text.replaceAll('﻿', '').trim();
    if (index != 0 || surah == 1 || surah == 9 || !text.startsWith('بِسْمِ')) {
      return text;
    }
    final words = text.split(' ');
    return words.length > 4 ? words.skip(4).join(' ') : text;
  }

  // ---- Önbellek ----

  Future<File> _cacheFile(int id) async {
    _cacheDir ??= await getApplicationSupportDirectory();
    return File('${_cacheDir!.path}/surah_v${_cacheVersion}_$id.json');
  }

  Future<List<Verse>?> _readCache(int id) async {
    try {
      final f = await _cacheFile(id);
      if (!await f.exists()) return null;
      final list = jsonDecode(await f.readAsString()) as List;
      return [for (final j in list) Verse.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(int id, List<Verse> verses) async {
    try {
      final f = await _cacheFile(id);
      await f.writeAsString(jsonEncode([for (final v in verses) v.toJson()]));
    } catch (_) {}
  }
}
