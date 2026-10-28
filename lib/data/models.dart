class Surah {
  const Surah({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.verseCount,
    required this.juz,
    required this.firstPage,
    required this.besmele,
    required this.info,
  });

  final int id;
  final String name;
  final String arabicName;
  final int verseCount;
  final int juz;
  final int firstPage;

  /// Surenin başında ayrıca besmele okunur mu (Fâtiha ve Tevbe'de hayır).
  final bool besmele;

  /// Sure hakkında kısa bilgi (düz metin).
  final String info;

  factory Surah.fromDiyanet(Map<String, dynamic> j) => Surah(
        id: _int(j['SureId']),
        name: j['SureNameTurkish'] as String,
        arabicName: j['SureNameArabic'] as String,
        verseCount: _int(j['AyetCount']),
        juz: _int(j['Cuz']),
        firstPage: _int(j['FirstPage']),
        besmele: j['BesmeleVisible'] == true,
        info: stripHtml(j['MealInfo'] as String? ?? ''),
      );
}

class Verse {
  const Verse({
    required this.surah,
    required this.number,
    required this.arabic,
    required this.meal,
    required this.page,
  });

  final int surah;
  final int number;
  final String arabic;
  final String meal;
  final int page;

  factory Verse.fromJson(Map<String, dynamic> j) => Verse(
        surah: j['s'] as int,
        number: j['n'] as int,
        arabic: j['a'] as String,
        meal: j['m'] as String,
        page: j['p'] as int,
      );

  Map<String, dynamic> toJson() =>
      {'s': surah, 'n': number, 'a': arabic, 'm': meal, 'p': page};
}

/// Bir kelimenin ayet içindeki zamanı (ms, ayet başından itibaren).
class WordTiming {
  const WordTiming(this.word, this.start, this.end);

  /// 0 tabanlı kelime sırası.
  final int word;
  final int start;
  final int end;
}

class VerseTiming {
  const VerseTiming(this.from, this.to, this.words);

  /// Sure ses dosyası içindeki başlangıç/bitiş (ms).
  final int from;
  final int to;
  final List<WordTiming> words;
}

/// Quran.com: sure ses dosyası, kelime zamanlamaları ve eşleşen Arapça kelimeler.
class PreciseSurah {
  const PreciseSurah(this.audioUrl, this.timings, this.words);

  final String audioUrl;
  final Map<int, VerseTiming> timings;
  final Map<int, List<String>> words;
}

/// Kaydedilmiş ayet.
class Bookmark {
  const Bookmark(this.surah, this.verse, this.snippet);

  final int surah;
  final int verse;
  final String snippet;

  String get key => '$surah:$verse';

  factory Bookmark.fromJson(Map<String, dynamic> j) =>
      Bookmark(j['s'] as int, j['v'] as int, j['t'] as String? ?? '');

  Map<String, dynamic> toJson() => {'s': surah, 'v': verse, 't': snippet};
}

int _int(Object? v) => v is int ? v : int.parse(v.toString());

String stripHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\n{2,}'), '\n')
    .trim();

/// Cüz başlangıçları (sure, ayet).
const juzStarts = <(int, int)>[
  (1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 83), (6, 111),
  (7, 88), (8, 41), (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75),
  (21, 1), (23, 1), (25, 21), (27, 56), (29, 46), (33, 31), (36, 28),
  (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
];

int juzOf(int surah, int verse) {
  for (var i = juzStarts.length - 1; i >= 0; i--) {
    final (s, v) = juzStarts[i];
    if (surah > s || (surah == s && verse >= v)) return i + 1;
  }
  return 1;
}

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String toArabicDigits(int n) =>
    n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

/// Arama için Türkçe karakterleri sadeleştirir.
String normalizeTr(String s) {
  const map = {
    'â': 'a', 'Â': 'a', 'î': 'i', 'Î': 'i', 'û': 'u', 'Û': 'u',
    'ı': 'i', 'I': 'i', 'İ': 'i', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g',
    'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o', 'ç': 'c', 'Ç': 'c',
    '’': '', "'": '', '-': '', ' ': '',
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(map[ch] ?? ch.toLowerCase());
  }
  return b.toString();
}
