import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/quran_repository.dart';
import '../data/settings.dart';
import '../data/words.dart';

class _Track {
  const _Track(this.verse, this.meal);

  /// 0 = besmele.
  final int verse;
  final bool meal;
}

/// Ayet ayet okuma. Hangi ayetin okunduğunu [currentVerse] ile bildirir.
class PlayerController extends ChangeNotifier {
  PlayerController(this._repo, this._settings) {
    _player.currentIndexStream.listen(_onIndex);
    _player.playerStateStream.listen(_onState);
    _player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 80),
          maxPeriod: const Duration(milliseconds: 250),
        )
        .listen(_onPosition);
    _player.playbackEventStream.listen((_) {}, onError: (Object e, _) {
      error = 'Ses yüklenemedi. İnternet bağlantınızı kontrol edin.';
      notifyListeners();
    });
    _settings.addListener(_onSettings);
    AudioSession.instance
        .then((s) => s.configure(const AudioSessionConfiguration.speech()));
  }

  final QuranRepository _repo;
  final Settings _settings;
  final _player = AudioPlayer();

  Surah? surah;
  List<Verse> verses = const [];
  List<_Track> _tracks = const [];
  AudioMode _mode = AudioMode.arabic;
  int _prevIndex = -1;

  /// Bu çalma listesinin Arapça hafızı.
  int _reciterId = 0;
  PreciseSurah? _precise;

  /// Sure sesi parçalanarak çalınıyorsa: ses adresi ve ayet sınırları.
  String? _clipUrl;
  Map<int, VerseTiming>? _clips;

  /// Ayet ayet çalınıyorsa kullanılan hafız (sure sesi alınamazsa Diyanet).
  Reciter _ayahReciter = AppConfig.reciters.first;

  /// Tahmini modda, çalan parçanın kelime bitiş oranları.
  List<double> _ends = const [];

  /// Okunan kelimenin sırası (ayet ya da meal içinde); -1 = yok.
  final word = ValueNotifier<int>(-1);

  /// Ön dinlemesi çalan hafız (ayarlar ekranı); null = yok.
  int? previewing;

  /// Hafızın sesini tanımak için Fâtiha'nın başını çalar. Açık oturumu kapatır.
  Future<void> previewReciter(int id) async {
    if (previewing == id) {
      previewing = null;
      await _player.stop();
      notifyListeners();
      return;
    }
    await stop();
    previewing = id;
    error = null;
    notifyListeners();
    try {
      final tag = MediaItem(
        id: 'preview-$id',
        title: 'Fâtiha · ön dinleme',
        album: "Kur'an-ı Kerim",
        artist: AppConfig.reciter(id).name,
      );
      final AudioSource source;
      final reciter = AppConfig.reciter(id);
      if (reciter.perAyah) {
        source = AudioSource.uri(Uri.parse(reciter.ayahUrl(1, 2)), tag: tag);
      } else {
        final p = await _repo.wordSync(reciter, 1);
        final (url, timings) = (p.audioUrl, p.timings);
        source = ClippingAudioSource(
          child: AudioSource.uri(Uri.parse(url)),
          start: Duration(milliseconds: timings[1]?.from ?? 0),
          end: Duration(milliseconds: timings[3]?.to ?? 15000),
          tag: tag,
        );
      }
      if (previewing != id) return;
      await _player.setAudioSources([source]);
      await _player.setSpeed(_settings.speed);
      unawaited(_player.play());
    } catch (_) {
      previewing = null;
      error = 'Ses yüklenemedi. İnternet bağlantınızı kontrol edin.';
      notifyListeners();
    }
  }

  /// Bu sure için tam kelime takibi kullanılıyor mu.
  bool get isPrecise => _precise != null;
  PreciseSurah? get precise => _precise;

  /// Okunmakta olan ayet; 0 = besmele, null = yok.
  int? currentVerse;
  bool currentIsMeal = false;
  bool playing = false;
  bool loading = false;
  bool repeatVerse = false;
  String? error;

  /// Sure bitince sıradaki sureye geçildiğinde artar; açık sayfa takip eder.
  int autoAdvanceCount = 0;

  bool get hasSession => surah != null;

  Verse? get currentVerseData => currentVerse == null || currentVerse == 0
      ? null
      : verses.elementAtOrNull(currentVerse! - 1);

  Future<void> playSurah(Surah s, List<Verse> v, {int fromVerse = 1}) async {
    error = null;
    previewing = null;
    surah = s;
    verses = v;
    _mode = _settings.audioMode;
    loading = true;
    currentVerse = fromVerse;
    word.value = -1;
    notifyListeners();

    _precise = null;
    _clipUrl = null;
    _clips = null;
    _reciterId = _settings.arabicReciter;
    final reciter = AppConfig.reciter(_reciterId);
    _ayahReciter = reciter.perAyah ? reciter : AppConfig.reciters.first;
    if (!reciter.perAyah && _mode != AudioMode.meal) {
      try {
        final p = _precise = await _repo.wordSync(reciter, s.id);
        _clipUrl = p.audioUrl;
        _clips = p.timings;
      } catch (_) {
        _precise = null;
        error = '${reciter.name} yüklenemedi, ${_ayahReciter.name} ile devam ediliyor.';
      }
    }
    final clips = _clips;

    final tracks = <_Track>[];
    void add(int verse) {
      // Quran.com sesinde besmele yoktur; archive.org'da ayet 0 olarak gelir.
      final arabicAvailable = clips == null || clips.containsKey(verse);
      if (_mode != AudioMode.meal && arabicAvailable) tracks.add(_Track(verse, false));
      if (_mode != AudioMode.arabic) tracks.add(_Track(verse, true));
    }

    if (s.besmele && fromVerse <= 1) add(0);
    for (var n = fromVerse; n <= v.length; n++) {
      add(n);
    }
    _tracks = tracks;
    _prevIndex = -1;

    try {
      await _player.setAudioSources(
        [for (final t in tracks) _source(s, t)],
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      await _player.setSpeed(_settings.speed);
      unawaited(_player.play());
    } catch (e) {
      error = 'Ses yüklenemedi. İnternet bağlantınızı kontrol edin.';
      loading = false;
      notifyListeners();
    }
  }

  /// Arapça okunuyorsa ve ayarlardan hafız değiştiyse.
  bool get _reciterChanged =>
      _settings.audioMode != AudioMode.meal && _reciterId != _settings.arabicReciter;

  AudioSource _source(Surah s, _Track t) {
    final clips = _clips;
    final clipUrl = _clipUrl;
    if (clips != null && clipUrl != null && !t.meal) {
      final timing = clips[t.verse]!;
      return ClippingAudioSource(
        child: AudioSource.uri(Uri.parse(clipUrl)),
        start: Duration(milliseconds: timing.from),
        end: Duration(milliseconds: timing.to),
        tag: MediaItem(
          id: '$clipUrl#${t.verse}',
          title: t.verse == 0 ? '${s.name} · Besmele' : '${s.name} · ${t.verse}. Ayet',
          album: "Kur'an-ı Kerim",
          artist: AppConfig.reciter(_reciterId).name,
        ),
      );
    }
    final url = t.meal
        ? AppConfig.mealAudio(s.id, t.verse)
        : _ayahReciter.ayahUrl(s.id, t.verse);
    return AudioSource.uri(
      Uri.parse(url),
      tag: MediaItem(
        id: url,
        title: t.verse == 0 ? '${s.name} · Besmele' : '${s.name} · ${t.verse}. Ayet',
        album: "Kur'an-ı Kerim",
        artist: t.meal ? 'Meal · ${AppConfig.mealReaderName}' : _ayahReciter.name,
      ),
    );
  }

  /// Bu sureden belirli bir ayeti okur.
  Future<void> playVerse(Surah s, List<Verse> v, int verse) async {
    final i = surah?.id == s.id &&
            _mode == _settings.audioMode &&
            !_reciterChanged
        ? _firstIndexOf(verse)
        : -1;
    if (i >= 0) {
      await _player.seek(Duration.zero, index: i);
      unawaited(_player.play());
    } else {
      await playSurah(s, v, fromVerse: verse);
    }
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      final s = surah;
      if (s != null && _tracks.isEmpty) {
        await playSurah(s, verses,
            fromVerse: (currentVerse ?? 1).clamp(1, verses.length));
        return;
      }
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero, index: 0);
      }
      unawaited(_player.play());
    }
  }

  Future<void> nextVerse() async {
    final s = surah;
    if (s == null) return;
    final next = (currentVerse ?? 0) + 1;
    if (next > verses.length) return;
    await playVerse(s, verses, next);
  }

  Future<void> previousVerse() async {
    final s = surah;
    if (s == null) return;
    final prev = (currentVerse ?? 1) - 1;
    if (prev < 1) {
      await playVerse(s, verses, 1);
      return;
    }
    await playVerse(s, verses, prev);
  }

  void toggleRepeat() {
    repeatVerse = !repeatVerse;
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    surah = null;
    currentVerse = null;
    _tracks = const [];
    word.value = -1;
    notifyListeners();
  }

  int _firstIndexOf(int verse) => _tracks.indexWhere((t) => t.verse == verse);

  void _onIndex(int? index) {
    if (index == null || index >= _tracks.length) return;
    final t = _tracks[index];

    // Ayet tekrarı: bir sonraki ayete geçildiyse geri sar.
    if (repeatVerse &&
        _prevIndex >= 0 &&
        index == _prevIndex + 1 &&
        _tracks[_prevIndex].verse != t.verse &&
        _tracks[_prevIndex].verse != 0) {
      final again = _firstIndexOf(_tracks[_prevIndex].verse);
      _prevIndex = -1;
      _player.seek(Duration.zero, index: again);
      return;
    }

    _prevIndex = index;
    currentVerse = t.verse;
    currentIsMeal = t.meal;
    _ends = _estimateFor(t);
    word.value = -1;
    if (t.verse > 0) _settings.setLastRead(surah!.id, t.verse);
    notifyListeners();
  }

  List<double> _estimateFor(_Track t) {
    if (!t.meal && _precise != null) return const [];
    final v = t.verse == 0 ? null : verses.elementAtOrNull(t.verse - 1);
    return t.meal
        ? estimateMeal(mealTokens(v?.meal ?? AppConfig.besmeleMeal))
        : estimateArabic(arabicTokens(v?.arabic ?? AppConfig.besmele));
  }

  void _onPosition(Duration position) {
    final index = _player.currentIndex;
    if (!_settings.wordHighlight || index == null || index >= _tracks.length) {
      word.value = -1;
      return;
    }
    final t = _tracks[index];
    final ms = position.inMilliseconds;
    final precise = _precise;

    if (!t.meal && precise != null) {
      final segments = precise.timings[t.verse]?.words ?? const <WordTiming>[];
      var w = -1;
      for (final seg in segments) {
        if (seg.start <= ms) {
          w = seg.word;
        } else {
          break;
        }
      }
      word.value = w;
      return;
    }

    final duration = _player.duration?.inMilliseconds ?? 0;
    if (duration <= 0 || _ends.isEmpty) {
      word.value = -1;
      return;
    }
    word.value = wordAtFraction(_ends, ms / duration);
  }

  void _onState(PlayerState state) {
    final wasPlaying = playing;
    playing = state.playing && state.processingState != ProcessingState.completed;
    loading = state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;

    if (state.processingState == ProcessingState.completed) {
      if (previewing != null && surah == null) previewing = null;
      _onCompleted();
    }
    if (wasPlaying != playing) _updateWakelock();
    notifyListeners();
  }

  bool _completing = false;

  Future<void> _onCompleted() async {
    final s = surah;
    if (s == null || _tracks.isEmpty || _completing) return;
    _completing = true;
    try {
      await _handleCompleted(s);
    } finally {
      _completing = false;
    }
  }

  Future<void> _handleCompleted(Surah s) async {
    if (repeatVerse && currentVerse != null && currentVerse! > 0) {
      await _player.seek(Duration.zero, index: _firstIndexOf(currentVerse!));
      unawaited(_player.play());
      return;
    }
    if (_settings.autoNext && s.id < 114) {
      try {
        final next = await _repo.surah(s.id + 1);
        final v = await _repo.verses(next.id);
        autoAdvanceCount++;
        await playSurah(next, v);
      } catch (_) {
        error = 'Sıradaki sure yüklenemedi.';
        notifyListeners();
      }
    } else {
      await _player.pause();
    }
  }

  void _onSettings() {
    if ((_player.speed - _settings.speed).abs() > 0.01) {
      _player.setSpeed(_settings.speed);
    }
    final s = surah;
    if (s != null &&
        (_mode != _settings.audioMode || _reciterChanged)) {
      final from = (currentVerse ?? 1).clamp(1, verses.length);
      if (playing) {
        playSurah(s, verses, fromVerse: from);
      } else {
        _mode = _settings.audioMode;
        _reciterId = _settings.arabicReciter;
        _tracks = const [];
      }
    }
    _updateWakelock();
  }

  void _updateWakelock() {
    if (playing && _settings.keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    _player.dispose();
    word.dispose();
    super.dispose();
  }
}
