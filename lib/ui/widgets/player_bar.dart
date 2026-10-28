import 'package:flutter/material.dart';

import '../../config.dart';
import '../../data/models.dart';
import '../../data/settings.dart';
import '../../main.dart';
import '../theme.dart';

/// Sure ekranının altındaki büyük oynatma çubuğu.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key, required this.surah, required this.onPlayHere});

  final Surah surah;

  /// Bu surede oturum yokken, ekrandaki ayetten başlatır.
  final VoidCallback onPlayHere;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.player, scope.settings]),
      builder: (context, _) {
        final player = scope.player;
        final settings = scope.settings;
        final here = player.surah?.id == surah.id;
        final verse = here ? player.currentVerse : null;

        final String status;
        if (player.error != null && here) {
          status = player.error!;
        } else if (verse == null) {
          status = 'Dinlemek için ▶ düğmesine dokunun';
        } else if (verse == 0) {
          status = 'Besmele okunuyor';
        } else {
          final page = player.currentVerseData?.page;
          status = '$verse. ayet${player.currentIsMeal ? ' (meal)' : ''}'
              '${page != null ? ' · sayfa $page' : ''}';
        }

        return Material(
          color: Theme.of(context).cardTheme.color,
          elevation: 8,
          shadowColor: Colors.black26,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        here && player.playing ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: player.error != null && here ? scheme.error : scheme.onSurface,
                          ),
                        ),
                      ),
                      _ModeButton(settings: settings),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Ayeti tekrarla',
                        iconSize: 30,
                        isSelected: player.repeatVerse,
                        selectedIcon: const Icon(Icons.repeat_one_on_rounded, color: AppColors.gold),
                        icon: Icon(Icons.repeat_one_rounded, color: scheme.onSurfaceVariant),
                        onPressed: player.toggleRepeat,
                      ),
                      IconButton(
                        tooltip: 'Önceki ayet',
                        iconSize: 38,
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: here ? player.previousVerse : null,
                      ),
                      SizedBox(
                        width: 68,
                        height: 68,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: here ? player.togglePlay : onPlayHere,
                          child: here && player.loading && !player.playing
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                )
                              : Icon(
                                  here && player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 40,
                                ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sonraki ayet',
                        iconSize: 38,
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: here ? player.nextVerse : null,
                      ),
                      IconButton(
                        tooltip: 'Durdur',
                        iconSize: 30,
                        icon: Icon(Icons.stop_rounded, color: scheme.onSurfaceVariant),
                        onPressed: here ? player.stop : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AudioMode>(
      tooltip: 'Ne okunsun?',
      initialValue: settings.audioMode,
      onSelected: (m) => settings.audioMode = m,
      itemBuilder: (_) => [
        for (final m in AudioMode.values)
          PopupMenuItem(
            value: m,
            child: Text(
              switch (m) {
                AudioMode.arabic => 'Arapça (${settings.reciter.name})',
                AudioMode.meal => 'Türkçe meal (${AppConfig.mealReaderName})',
                AudioMode.both => 'Önce Arapça, sonra meal',
              },
              style: const TextStyle(fontSize: 16),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(settings.audioMode.label,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}
