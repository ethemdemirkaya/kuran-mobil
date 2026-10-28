/// Uygulama genelindeki sabitler.
class AppConfig {
  /// Diyanet Açık Kaynak Kur'an API.
  static const diyanetBase = 'https://acikkaynakkuran-dev.diyanet.gov.tr/api/v1';

  /// `--dart-define-from-file=secrets.json` ile verilir.
  static const diyanetToken = String.fromEnvironment('DIYANET_TOKEN');

  /// Diyanet anahtarının erişemediği ayetler ve diğer mealler için kaynak.
  static const fallbackBase = 'https://api.alquran.cloud/v1';

  /// Diyanet'in ayet ayet ses dosyaları: `{klasör}/{sure}_{ayet}.mp3`,
  /// ayet 0 = besmele.
  static const audioBase = 'https://webdosya.diyanet.gov.tr/kuran/kuranikerim/Sound';
  static const everyAyahBase = 'https://everyayah.com/data';
  static const archiveBase = 'https://archive.org/download';
  static const mealReader = 'tr_seyfullahkartal';
  static const mealReaderName = 'Seyfullah Kartal';

  static String mealAudio(int surah, int verse) =>
      '$audioBase/$mealReader/${surah}_$verse.mp3';

  /// Quran.com: sure sesi + kelime zamanlaması, ve eşleşen metin.
  static const preciseBase = 'https://api.qurancdn.com/api/qdc/audio/reciters';
  static const preciseTextBase = 'https://api.quran.com/api/v4/quran/verses/uthmani';

  static const reciters = <Reciter>[
    Reciter(0, 'Osman Şahin', ReciterSource.diyanet, 'ar_osmansahin'),
    Reciter(1001, 'Mahir el-Muaykılî', ReciterSource.everyAyah, 'Maher_AlMuaiqly_64kbps'),
    Reciter(1002, 'İshak Danış', ReciterSource.archive, 'ishak_danish'),
    Reciter(1003, 'Fatih Çollak', ReciterSource.archive, 'rabieaaa2015_yahoo_002132432'),
    Reciter(7, 'Mişari Raşid el-Afasi', ReciterSource.quranCom),
    Reciter(6, 'Mahmud Halil el-Husarî', ReciterSource.quranCom),
    Reciter(12, 'Mahmud Halil el-Husarî (öğretici)', ReciterSource.quranCom),
    Reciter(2, 'Abdulbasit Abdussamed', ReciterSource.quranCom),
    Reciter(1, 'Abdulbasit Abdussamed (mücevved)', ReciterSource.quranCom),
    Reciter(9, 'Muhammed Sıddık el-Minşavi', ReciterSource.quranCom),
    Reciter(3, 'Abdurrahman es-Sudeys', ReciterSource.quranCom),
    Reciter(10, 'Suud eş-Şureym', ReciterSource.quranCom),
    Reciter(4, 'Ebu Bekir eş-Şatri', ReciterSource.quranCom),
    Reciter(5, 'Hani er-Rifai', ReciterSource.quranCom),
    Reciter(97, 'Yasir ed-Devseri', ReciterSource.quranCom),
    Reciter(161, 'Halife et-Tuneyci', ReciterSource.quranCom),
  ];

  static Reciter reciter(int id) =>
      reciters.firstWhere((r) => r.id == id, orElse: () => reciters.first);

  static const meals = <MealSource>[
    MealSource('diyanet', 'Diyanet İşleri'),
    MealSource('tr.yazir', 'Elmalılı Hamdi Yazır'),
  ];

  static MealSource meal(String id) =>
      meals.firstWhere((m) => m.id == id, orElse: () => meals.first);

  static const besmele = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحٖیمِ';
  static const besmeleMeal = 'Rahmân ve rahîm olan Allah’ın adıyla';
}

enum ReciterSource {
  /// Diyanet ayet ayet; kelimeler tahmini.
  diyanet,

  /// everyayah.com ayet ayet; kelimeler tahmini.
  everyAyah,

  /// Quran.com sure sesi; kelimeler tam zamanlamalı.
  quranCom,

  /// archive.org sure sesi; ayet sınırları uygulamayla gelen dosyadan,
  /// kelimeler tahmini.
  archive,
}

class Reciter {
  const Reciter(this.id, this.name, this.source, [this.folder = '']);

  final int id;
  final String name;
  final ReciterSource source;
  final String folder;

  bool get precise => source == ReciterSource.quranCom;

  /// Kelime zamanlaması var mı (Quran.com ya da uygulamayla gelen hizalama).
  bool get wordSync => precise || source == ReciterSource.archive;

  /// Ayet ayet dosyası var mı (yoksa sure sesi parçalanarak çalınır).
  bool get perAyah =>
      source == ReciterSource.diyanet || source == ReciterSource.everyAyah;

  /// archive: sure ses dosyası ve ayet sınırları.
  String surahUrl(int surah) => '${AppConfig.archiveBase}/$folder/${_pad(surah)}.mp3';
  String get timingsAsset => 'assets/data/timings_$id.json';

  /// Ayet ayet kaydı olan hafızlar için ses adresi (ayet 0 = besmele).
  String ayahUrl(int surah, int verse) => switch (source) {
        ReciterSource.diyanet => '${AppConfig.audioBase}/$folder/${surah}_$verse.mp3',
        ReciterSource.everyAyah => verse == 0
            ? '${AppConfig.everyAyahBase}/$folder/001001.mp3'
            : '${AppConfig.everyAyahBase}/$folder/${_pad(surah)}${_pad(verse)}.mp3',
        ReciterSource.quranCom ||
        ReciterSource.archive =>
          throw UnsupportedError('Sure sesi kullanılır'),
      };

  static String _pad(int n) => n.toString().padLeft(3, '0');
}

class MealSource {
  const MealSource(this.id, this.name);

  /// 'diyanet' ya da alquran.cloud baskı kimliği.
  final String id;
  final String name;

  bool get isDiyanet => id == 'diyanet';
}
