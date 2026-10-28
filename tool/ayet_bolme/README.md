# Ayet ve kelime hizalama (archive.org hafızları)

İshak Danış ve Fatih Çollak'ın yalnızca sure sure kaydı var. Bu betikler her
sure kaydında ayet ve kelime başlarını bulur ve `assets/data/timings_<id>.json`
dosyalarını üretir.

## Yöntem

1. **Giriş:** Sure başındaki istiaze/besmele sessizliklerden bulunur
   (`align.align_intro`) ve ayrı parça olarak saklanır (`"b"`).
2. **Sesi sesle hizalama:** Kayıt, kelime zamanları bilinen üç Quran.com
   hafızına (Husarî, Minşavi, Alafasi) MFCC + DTW ile hizalanır
   (`dtw_align.py`): 1 sn → 200 ms → ayet ayet, üç aşamalı.
3. **Uzlaşı:** Her ayet başı üç referansın ortancasıdır. Referansların
   250 ms içinde uyuştuğu kelimeler çapa olur; aradakiler kelime süre
   katsayılarıyla dağıtılır (`pipeline.py`).

## Doğrulama (`eval_consensus.py`)

Gerçek zamanı bilinen bir hafız hedef alınır, kendisi referans listesine
konmaz:

| Hedef | Ayet başı >1,5 sn | Tam kelime | ±1 kelime |
| --- | --- | --- | --- |
| Şureym (orta tempo) | %1,7 | %75 | %95 |
| Husarî (çok yavaş) | %20 | %58 | %87 |

Danış ve Çollak'ın temposu Şureym'e yakındır. Eski yöntem (yalnızca
sessizlikler) Çollak'ta ayetleri 20+ saniye kaydırıyordu.

## Çalıştırma

```bash
pip install numpy scipy numba   # ffmpeg/ffprobe de gerekli
python pipeline.py 0 3          # 3 paralel işlem: 0, 1, 2
python pipeline.py 1 3
python pipeline.py 2 3
```

Fatih Çollak'ın 38 ve 52. sure dosyaları archive.org'da bozuk (başında PNG
var); o iki surede uygulama Osman Şahin'e geçer.
