# Kur'an-ı Kerim — sesli, ayet ayet takipli

Hafif, üyelik gerektirmeyen bir Flutter uygulaması. Sure açılır, ▶'ye basılır;
okunan ayet altın çerçeveyle vurgulanır ve ekran onu kendiliğinden takip eder.

## Özellikler

- 114 sure, 30 cüz, sure arama (`yasin`, `36` gibi)
- Ayet ayet dinleme: **Arapça** (Osman Şahin), **Türkçe meal** (Seyfullah Kartal) ya da **ikisi sırayla**
- Okunan ayet vurgulanır, "Okunuyor / Meal okunuyor" etiketi gösterilir, liste otomatik kayar
- **Okunan kelime boyanır** (Arapça ve mealde). İki seçenek:
  - *Tahmini* (varsayılan): Diyanet sesi; kelime zamanı kelime uzunluğundan hesaplanır
  - *Tam kelime takibi* (Ayarlar): Arapça ses ve metin Quran.com hafızından (Alafasi,
    Husarî, Abdulbasit, Minşavi); kelimeler gerçek zamanlamayla boyanır. Meal yine tahminidir.
- 16 hafız arasından seçim, her birini ▶ ile ön dinleme: Osman Şahin (Diyanet),
  Mahir el-Muaykılî (EveryAyah), İshak Danış ve Fatih Çollak (archive.org) ve
  12 Quran.com hafızı
- İshak Danış ve Fatih Çollak için ayet ve kelime zamanları, kayıtların üç
  Quran.com hafızına sesle hizalanmasıyla üretildi (bkz. `tool/ayet_bolme`)
- Meal seçimi: Diyanet İşleri ya da Elmalılı Hamdi Yazır (sesli meal her zaman Diyanet'tir)
- Üst çubukta o an bulunulan **sayfa · cüz · ayet**, ayetler arasında sayfa/cüz ayraçları
- Ayet tekrarı, önceki/sonraki ayet, hız (yavaş/normal/hızlı), sure bitince sonrakine geçme
- Ekran kapalıyken ve bildirimden kontrol (arka planda çalma)
- Kaldığın yerden devam, ayet kaydetme (kaydırarak silme), uzun basınca kopyalama
- Büyük, ayarlanabilir yazı boyutları; açık/koyu tema
- Açılan sureler cihazda saklanır, sonra internetsiz de okunur

## Veri kaynakları

| Ne | Nereden |
| --- | --- |
| Sure listesi, Arapça metin, meal, sayfa numaraları, Amasya yazı tipi | [Diyanet Açık Kaynak Kur'an API](https://acikkaynakkuran-dev.diyanet.gov.tr/swagger/documentation) (`/api/v1/chapters`, `/api/v1/chapters/{id}`, `/api/v1/juz/1`, `/api/v1/fonts`) |
| Ayet ayet ses | `https://webdosya.diyanet.gov.tr/kuran/kuranikerim/Sound/{okuyucu}/{sure}_{ayet}.mp3` (ayet `0` = besmele) |
| Tam kelime takibi | Quran.com — `api.qurancdn.com/api/qdc/audio/reciters/{id}/audio_files?chapter={n}&segments=true` (sure sesi + kelime zamanları), `api.quran.com/api/v4/quran/verses/uthmani` (metin) |
| İshak Danış / Fatih Çollak sesi | `archive.org/download/{ishak_danish, rabieaaa2015_yahoo_002132432}/{sss}.mp3` + `assets/data/timings_100{2,3}.json` |
| Mahir el-Muaykılî sesi | `everyayah.com/data/Maher_AlMuaiqly_64kbps/{sss}{aaa}.mp3` |
| Elmalılı meali | alquran.cloud — `tr.yazir` |
| Yedek metin | [alquran.cloud](https://alquran.cloud) — `quran-uthmani` + `tr.diyanet` |

**Not:** Geliştirici anahtarı şu an yalnızca 1. cüzün tamamına, diğer surelerin
ise ilk 9 ayetine erişebiliyor (API: *"Anahtarınız yalnızca ilk 1. cüze erişebilir"*).
Eksik ayetler yedek kaynaktan tamamlanır. Anahtarın yetkisi genişletilirse
uygulama kod değişikliği olmadan tamamen Diyanet verisini kullanır
(önbelleği temizlemek için uygulama verisini silmek yeterli).

## Logo ve açılış ekranı

Görseller `assets/branding/` altında. Değiştirirsen yeniden üret:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Çalıştırma

```bash
cp secrets.example.json secrets.json   # içine Diyanet API anahtarını yaz
flutter pub get
flutter run --dart-define-from-file=secrets.json
```

APK (anneye kurmak için):

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=secrets.json
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`secrets.json` git'e girmez. Anahtar verilmezse uygulama yine çalışır, tüm
metni yedek kaynaktan alır.
