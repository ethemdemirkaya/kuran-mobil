import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_mobil/data/words.dart';

void main() {
  test('vakıf ve hizb işaretleri kelimeye bağlanır', () {
    expect(arabicTokens('ذَٰلِكَ ٱلْكِتَـٰبُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى').length, 6);
    expect(arabicTokens('۞ إِنَّ ٱللَّهَ').first, '۞ إِنَّ');
  });

  test('Arapça: medd ve ayet sonu kelimeyi uzatır', () {
    final ends = estimateArabic(arabicTokens('الٓمٓ ذَلِكَ الْكِتَابُ'));
    final first = ends[0];
    final second = ends[1] - ends[0];
    final last = ends[2] - ends[1];
    expect(first, greaterThan(second)); // medd
    expect(last, greaterThan(second)); // ayet sonu
  });

  test('Meal: hece sayısı ve virgül süreyi artırır', () {
    final ends = estimateMeal(mealTokens('ve kıyamet, günü'));
    final ve = ends[0];
    final kiyamet = ends[1] - ends[0];
    expect(kiyamet, greaterThan(ve * 2));
  });

  test('tahmini zamanlama artan ve 1 ile biter', () {
    final ends = estimateMeal(mealTokens('Ey iman edenler! Sözleşmeleri yerine getirin.'));
    expect(ends.length, 6);
    for (var i = 1; i < ends.length; i++) {
      expect(ends[i], greaterThan(ends[i - 1]));
    }
    expect(ends.last, closeTo(1, 1e-9));
    expect(wordAtFraction(ends, 0), 0);
    expect(wordAtFraction(ends, 0.999), 5);
  });
}
