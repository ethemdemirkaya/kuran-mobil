import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../audio/player_controller.dart';
import '../config.dart';
import '../data/models.dart';
import '../data/words.dart';
import '../main.dart';
import 'theme.dart';
import 'widgets/player_bar.dart';
import 'widgets/settings_sheet.dart';

class SurahScreen extends StatefulWidget {
  const SurahScreen({super.key, required this.surah, this.initialVerse = 1});

  final Surah surah;
  final int initialVerse;

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  final _topVerse = ValueNotifier<int>(1);
  late Future<List<Verse>> _verses;
  List<Verse> _loaded = const [];
  int? _followedVerse;
  late int _seenAdvance;
  PlayerController? _player;

  /// Tam kelime takibi açıkken gösterilen Quran.com metni.
  Map<int, List<String>>? _preciseWords;
  int? _preciseFor;

  /// Diyanet dışındaki meal seçiliyse onun metni.
  Map<int, String>? _altMeal;
  String _mealFor = 'diyanet';

  Surah get surah => widget.surah;

  @override
  void initState() {
    super.initState();
    _topVerse.value = widget.initialVerse;
    _load();
    _positions.itemPositions.addListener(_onPositions);
    AppScope.of(context).settings
      ..addListener(_loadPrecise)
      ..addListener(_loadMeal);
    _loadPrecise();
    _loadMeal();
  }

  void _loadMeal() {
    final source = AppScope.of(context).settings.meal;
    if (source.id == _mealFor) return;
    _mealFor = source.id;
    if (source.isDiyanet) {
      setState(() => _altMeal = null);
      return;
    }
    AppScope.of(context).repo.altMeal(surah.id, source.id).then((m) {
      if (mounted && _mealFor == source.id) setState(() => _altMeal = m);
    }, onError: (_) {});
  }

  void _loadPrecise() {
    final settings = AppScope.of(context).settings;
    final reciter = settings.reciter;
    final want = reciter.wordSync ? reciter.id : null;
    if (want == _preciseFor) return;
    _preciseFor = want;
    if (want == null) {
      setState(() => _preciseWords = null);
      return;
    }
    AppScope.of(context).repo.wordSync(settings.reciter, surah.id).then((p) {
      if (mounted && _preciseFor == want) setState(() => _preciseWords = p.words);
    }, onError: (_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = AppScope.of(context).player;
    if (identical(player, _player)) return;
    _player?.removeListener(_onPlayer);
    _player = player..addListener(_onPlayer);
    _seenAdvance = player.autoAdvanceCount;
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayer);
    AppScope.of(context).settings
      ..removeListener(_loadPrecise)
      ..removeListener(_loadMeal);
    _positions.itemPositions.removeListener(_onPositions);
    _topVerse.dispose();
    super.dispose();
  }

  void _load() {
    _verses = AppScope.of(context).repo.verses(surah.id).then((v) => _loaded = v);
  }

  void _onPositions() {
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0.08)
        .map((p) => p.index);
    if (visible.isEmpty) return;
    final first = visible.reduce((a, b) => a < b ? a : b);
    _topVerse.value = first == 0 ? 1 : first;
  }

  void _onPlayer() {
    final player = AppScope.of(context).player;
    final route = ModalRoute.of(context);

    // Sure bitip sıradakine geçildiyse sayfayı da çevir.
    if (player.autoAdvanceCount != _seenAdvance) {
      _seenAdvance = player.autoAdvanceCount;
      final next = player.surah;
      if (next != null && next.id == surah.id + 1 && (route?.isCurrent ?? false)) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, _, _) => SurahScreen(surah: next),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ));
        return;
      }
    }

    if (player.surah?.id != surah.id) return;
    final verse = player.currentVerse;
    if (verse == null || verse == _followedVerse || !_scroll.isAttached) return;
    _followedVerse = verse;
    _ensureVisible(verse);
  }

  /// Okunan ayet ekranda değilse ona kaydır.
  void _ensureVisible(int verse) {
    final p = _positions.itemPositions.value.where((p) => p.index == verse).firstOrNull;
    final fullyVisible = p != null && p.itemLeadingEdge >= 0 && p.itemTrailingEdge <= 0.85;
    if (fullyVisible) return;
    _scroll.scrollTo(
      index: verse,
      alignment: 0.08,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  void _playFrom(int verse) {
    if (_loaded.isEmpty) return;
    final player = AppScope.of(context).player;
    _followedVerse = verse;
    player.playVerse(surah, _loaded, verse);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ValueListenableBuilder<int>(
          valueListenable: _topVerse,
          builder: (context, top, _) {
            final page = _loaded.elementAtOrNull(top - 1)?.page ?? surah.firstPage;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${surah.name} Suresi'),
                Text(
                  'Sayfa $page · ${juzOf(surah.id, top)}. cüz · $top. ayet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Yazı boyutu ve ayarlar',
            iconSize: 28,
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: () => showSettingsSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<Verse>>(
        future: _verses,
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(onRetry: () => setState(_load));
          }
          final verses = snap.data;
          if (verses == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListenableBuilder(
            listenable: Listenable.merge([scope.settings, scope.player]),
            builder: (context, _) {
              final player = scope.player;
              final playingHere = player.surah?.id == surah.id;
              final current = playingHere ? player.currentVerse : null;
              final precise = playingHere && player.isPrecise
                  ? player.precise!.words
                  : _preciseWords;
              return ScrollablePositionedList.builder(
                itemScrollController: _scroll,
                itemPositionsListener: _positions,
                initialScrollIndex:
                    widget.initialVerse > 1 ? widget.initialVerse.clamp(0, verses.length) : 0,
                initialAlignment: widget.initialVerse > 1 ? 0.05 : 0,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: verses.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _SurahHeader(
                      surah: surah,
                      besmeleActive: current == 0,
                    );
                  }
                  final v = verses[i - 1];
                  final prev = i > 1 ? verses[i - 2] : null;
                  return _VerseTile(
                    verse: v,
                    arabicWords: precise?[v.number] ?? arabicTokens(v.arabic),
                    meal: _altMeal?[v.number] ?? v.meal,
                    showPageMark: prev != null && prev.page != v.page,
                    showJuzMark: prev != null &&
                        juzOf(v.surah, v.number) != juzOf(prev.surah, prev.number),
                    active: current == v.number,
                    readingMeal: current == v.number && player.currentIsMeal,
                    onPlay: () => _playFrom(v.number),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: PlayerBar(
        surah: surah,
        onPlayHere: () => _playFrom(_topVerse.value.clamp(1, surah.verseCount)),
      ),
    );
  }
}

class _SurahHeader extends StatefulWidget {
  const _SurahHeader({required this.surah, required this.besmeleActive});

  final Surah surah;
  final bool besmeleActive;

  @override
  State<_SurahHeader> createState() => _SurahHeaderState();
}

class _SurahHeaderState extends State<_SurahHeader> {
  bool _infoOpen = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.surah;
    final scheme = Theme.of(context).colorScheme;
    final settings = AppScope.of(context).settings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [AppColors.green, AppColors.greenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  s.arabicName,
                  style: const TextStyle(fontFamily: 'Amasya', fontSize: 40, color: Color(0xFFF1DDAF)),
                ),
                Text(
                  '${s.name} Suresi',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.verseCount} ayet · ${s.juz}. cüz · sayfa ${s.firstPage}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
                ),
                if (s.info.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () => setState(() => _infoOpen = !_infoOpen),
                    icon: Icon(_infoOpen ? Icons.expand_less_rounded : Icons.info_outline_rounded),
                    label: Text(_infoOpen ? 'Kapat' : 'Sure hakkında', style: const TextStyle(fontSize: 15)),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _infoOpen
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 6),
                            child: Text(
                              s.info,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ],
            ),
          ),
          if (s.besmele)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: widget.besmeleActive ? AppColors.gold.withValues(alpha: 0.15) : null,
                border: Border.all(
                  color: widget.besmeleActive ? AppColors.gold : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                AppConfig.besmele,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amasya',
                  fontSize: settings.arabicSize * 0.95,
                  color: scheme.primary,
                  height: 1.8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerseTile extends StatelessWidget {
  const _VerseTile({
    required this.verse,
    required this.arabicWords,
    required this.meal,
    required this.showPageMark,
    required this.showJuzMark,
    required this.active,
    required this.readingMeal,
    required this.onPlay,
  });

  final Verse verse;
  final List<String> arabicWords;
  final String meal;
  final bool showPageMark;
  final bool showJuzMark;
  final bool active;
  final bool readingMeal;
  final VoidCallback onPlay;

  void _copy(BuildContext context, String surahName) {
    Clipboard.setData(ClipboardData(
      text: '${verse.arabic}\n\n$meal\n($surahName, ${verse.number})',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayet kopyalandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final scheme = Theme.of(context).colorScheme;
    final bookmarked = settings.isBookmarked(verse.surah, verse.number);
    final cardColor = Theme.of(context).cardTheme.color;

    return Column(
      children: [
        if (showPageMark || showJuzMark)
          _PageMark(
            page: verse.page,
            juz: showJuzMark ? juzOf(verse.surah, verse.number) : null,
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: active ? Color.alphaBlend(AppColors.gold.withValues(alpha: 0.12), cardColor!) : cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? AppColors.gold : scheme.outlineVariant.withValues(alpha: 0.5),
                width: active ? 2 : 1,
              ),
              boxShadow: active
                  ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4))]
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onLongPress: () async {
                final name = (await scope.repo.surah(verse.surah)).name;
                if (context.mounted) _copy(context, name);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        VerseBadge(verse.number, active: active),
                        if (active) ...[
                          const SizedBox(width: 10),
                          _ReadingChip(meal: readingMeal),
                        ],
                        const Spacer(),
                        IconButton(
                          tooltip: bookmarked ? 'Kaydı kaldır' : 'Kaydet',
                          iconSize: 28,
                          color: bookmarked ? AppColors.gold : scheme.onSurfaceVariant,
                          icon: Icon(bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                          onPressed: () => settings.toggleBookmark(verse),
                        ),
                        IconButton(
                          tooltip: 'Bu ayetten dinle',
                          iconSize: 30,
                          color: scheme.primary,
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          onPressed: onPlay,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 4),
                      child: _WordText(
                        words: arabicWords,
                        suffix: ' ﴿${toArabicDigits(verse.number)}﴾',
                        word: active && !readingMeal && settings.wordHighlight
                            ? scope.player.word
                            : null,
                        rtl: true,
                        style: TextStyle(
                          fontFamily: 'Amasya',
                          fontSize: settings.arabicSize,
                          height: 2.0,
                          color: active && !readingMeal ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (settings.showMeal) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _WordText(
                          words: mealTokens(meal),
                          // Sesli meal Diyanet mealini okur; başka meal seçiliyse eşleşmez.
                          word: active &&
                                  readingMeal &&
                                  settings.wordHighlight &&
                                  settings.meal.isDiyanet
                              ? scope.player.word
                              : null,
                          style: TextStyle(
                            fontSize: settings.mealSize,
                            height: 1.55,
                            color: active && readingMeal ? scheme.primary : scheme.onSurface.withValues(alpha: 0.85),
                            fontWeight: active && readingMeal ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kelimelerden oluşan metin; [word] verilirse o an okunan kelimeyi boyar.
class _WordText extends StatelessWidget {
  const _WordText({
    required this.words,
    required this.style,
    this.word,
    this.suffix = '',
    this.rtl = false,
  });

  final List<String> words;
  final TextStyle style;
  final ValueNotifier<int>? word;
  final String suffix;
  final bool rtl;

  Widget _build(BuildContext context, int highlighted) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mark = style.copyWith(
      color: dark ? Colors.black : scheme.onSurface,
      backgroundColor: AppColors.gold.withValues(alpha: dark ? 0.85 : 0.38),
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (var i = 0; i < words.length; i++) ...[
            TextSpan(text: words[i], style: i == highlighted ? mark : null),
            if (i < words.length - 1) const TextSpan(text: ' '),
          ],
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
      textAlign: rtl ? TextAlign.right : TextAlign.start,
      textDirection: rtl ? TextDirection.rtl : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = word;
    if (w == null) return _build(context, -1);
    return ValueListenableBuilder<int>(
      valueListenable: w,
      builder: (context, i, _) => _build(context, i),
    );
  }
}

class _ReadingChip extends StatelessWidget {
  const _ReadingChip({required this.meal});

  final bool meal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            meal ? 'Meal okunuyor' : 'Okunuyor',
            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PageMark extends StatelessWidget {
  const _PageMark({required this.page, this.juz});

  final int page;
  final int? juz;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = Expanded(child: Divider(color: AppColors.gold.withValues(alpha: 0.5)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              juz != null ? '$juz. Cüz · Sayfa $page' : 'Sayfa $page',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text(
              'Sure yüklenemedi.\nİnternet bağlantınızı kontrol edip tekrar deneyin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}
