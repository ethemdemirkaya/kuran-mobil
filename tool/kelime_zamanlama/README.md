# Kelime boyama katsayıları

`lib/data/words.dart` içindeki Arapça kelime süre katsayıları buradan geldi.

- Veri: Quran.com'daki 8 hafızın gerçek kelime zamanlamaları
  (`api.qurancdn.com/api/qdc/audio/reciters/{id}/audio_files?chapter=N&segments=true`).
- Eğitim: Husarî, Alafasi, Minşavi, Abdulbasit — Bakara ve Kehf.
- Test: Sudeys, Rifai, Şureym, Şatri — Yâsîn, Rahmân, Mülk, A'lâ (hiç görülmemiş).
- Ölçüt: ses boyunca her 20 ms'de "boyanan kelime doğru mu".

| Yöntem | Tam kelime | ±1 kelime |
| --- | --- | --- |
| Eski (harf sayısı) | %62 | %95 |
| Ayarlı katsayılar | %77 | %98 |
| + nefes aralarına sabitleme (`wordsync.py`) | ek kazanç yok | |

`tune.py` katsayıları arar, `tune2.py` baş/son sessizlik payını, `exp2.py`
nefes sabitlemeyle karşılaştırır. `beta_tuned.json` harf=1.75 ölçeğindedir;
Dart'ta harf=1'e bölünmüş hali kullanılır.
