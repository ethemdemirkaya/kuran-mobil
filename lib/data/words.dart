/// Ayet metnini boyanabilir kelimelere böler ve kelime zamanlamasını tahmin eder.
library;

final _arabicLetter = RegExp('[ء-يٱ-ۓ]');

/// Arapça metni kelimelere böler. Harf içermeyen işaretler (vakıf, ۞) yanındaki
/// kelimeye bağlanır; böylece kelime sırası Quran.com zamanlamasıyla örtüşür.
List<String> arabicTokens(String text) {
  final out = <String>[];
  var prefix = '';
  for (final part in text.trim().split(RegExp(r'\s+'))) {
    if (part.isEmpty) continue;
    if (_arabicLetter.hasMatch(part)) {
      out.add('$prefix$part');
      prefix = '';
    } else if (out.isNotEmpty) {
      out[out.length - 1] = '${out.last} $part';
    } else {
      prefix = '$prefix$part ';
    }
  }
  return out;
}

List<String> mealTokens(String text) =>
    text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Her kelimenin bitiş anı, ayet süresinin oranı olarak (0..1).
///
/// Katsayılar 8 hafızın (Quran.com) gerçek kelime zamanlamalarından, "o an
/// doğru kelime boyansın" hedefiyle ayarlandı. Görmediği hafız ve surelerde
/// doğru kelime oranı %62'den %77'ye çıktı (±1 kelimeyle %98).
List<double> estimateArabic(List<String> words) => _cumulative([
      for (var i = 0; i < words.length; i++)
        _arabicWeight(words[i], last: i == words.length - 1),
    ], lead: 0.34);

List<double> estimateMeal(List<String> words) => _cumulative([
      for (var i = 0; i < words.length; i++)
        _mealWeight(words[i], last: i == words.length - 1),
    ], lead: 0.5);

double _arabicWeight(String w, {required bool last}) {
  var weight = 0.0;
  var pause = false;
  for (final r in w.runes) {
    if (_arabicLetter.hasMatch(String.fromCharCode(r))) {
      weight += 1;
    } else if (r == 0x0653) {
      weight += 4.22; // medd (uzatma)
    } else if (r == 0x0670 || r == 0x0656 || r == 0x06E5 || r == 0x06E6) {
      weight += 0.2; // küçük elif / vav / ye
    } else if (r == 0x0651) {
      weight += 1.0; // şedde
    } else if (r == 0x064B || r == 0x064C || r == 0x064D || (r >= 0x08F0 && r <= 0x08F2)) {
      weight += 1.34; // tenvin
    } else if (r >= 0x06D6 && r <= 0x06DC) {
      pause = true; // vakıf: durulan kelime uzatılır
    }
  }
  if (pause) weight += 2.29;
  if (last) weight += 3.78; // ayet sonunda uzatma
  return weight < 0.11 ? 0.11 : weight;
}

const _turkishVowels = 'aeıioöuüâîûAEIİOÖUÜÂÎÛ';

/// Türkçede okuma süresini hece sayısı belirler; noktalamada durulur.
double _mealWeight(String w, {required bool last}) {
  var syllables = 0;
  for (final ch in w.split('')) {
    if (_turkishVowels.contains(ch)) syllables++;
  }
  var weight = 0.4 + (syllables == 0 ? 0.6 : syllables.toDouble());
  final end = w.replaceAll(RegExp(r'''["”’'»)]+$'''), '');
  final mark = end.isEmpty ? '' : end[end.length - 1];
  if (mark == ',') weight += 1.2;
  if (';:'.contains(mark) && mark.isNotEmpty) weight += 1.5;
  if ('.!?'.contains(mark) && mark.isNotEmpty && !last) weight += 2.0;
  return weight;
}

List<double> _cumulative(List<double> weights, {required double lead}) {
  final total = weights.fold<double>(lead, (a, b) => a + b);
  var acc = lead;
  return [
    for (final w in weights) (acc += w) / total,
  ];
}

/// Tahmini oranlardan, verilen andaki kelimenin sırasını bulur.
int wordAtFraction(List<double> ends, double fraction) {
  for (var i = 0; i < ends.length; i++) {
    if (fraction < ends[i]) return i;
  }
  return ends.length - 1;
}
