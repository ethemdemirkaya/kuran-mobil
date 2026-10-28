import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_mobil/data/models.dart';

void main() {
  test('juzOf cüz sınırlarını doğru bulur', () {
    expect(juzOf(1, 1), 1);
    expect(juzOf(2, 141), 1);
    expect(juzOf(2, 142), 2);
    expect(juzOf(18, 74), 15);
    expect(juzOf(18, 75), 16);
    expect(juzOf(114, 6), 30);
  });

  test('normalizeTr Türkçe aramayı sadeleştirir', () {
    expect(normalizeTr('Yâsîn'), 'yasin');
    expect(normalizeTr('Âl-i İmrân'), 'aliimran');
    expect(normalizeTr('İhlâs'), 'ihlas');
  });

  test('toArabicDigits', () {
    expect(toArabicDigits(255), '٢٥٥');
  });

  test('Surah.fromDiyanet', () {
    final s = Surah.fromDiyanet({
      'SureId': 2,
      'SureNameTurkish': 'Bakara',
      'SureNameArabic': 'الْبَقَرَةِ',
      'BesmeleVisible': true,
      'AyetCount': 286,
      'Cuz': 1,
      'FirstPage': 2,
      'MealInfo': '<p>Medine <b>döneminde</b> inmiştir.</p>',
    });
    expect(s.verseCount, 286);
    expect(s.besmele, isTrue);
    expect(s.info, 'Medine döneminde inmiştir.');
  });
}
