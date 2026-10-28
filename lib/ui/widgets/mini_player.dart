import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../main.dart';
import '../theme.dart';

/// Ana ekranda, okuma devam ederken görünen küçük oynatıcı.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.onOpen});

  final void Function(Surah, {int verse}) onOpen;

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final s = player.surah;
        if (s == null) return const SizedBox.shrink();
        final verse = player.currentVerse ?? 1;
        return Material(
          color: AppColors.green,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => onOpen(s, verse: verse < 1 ? 1 : verse),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: Color(0xFFF1DDAF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${s.name} Suresi',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                          Text(
                            verse == 0 ? 'Besmele' : '$verse. ayet okunuyor',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      iconSize: 38,
                      color: Colors.white,
                      icon: Icon(player.playing ? Icons.pause_circle_rounded : Icons.play_circle_rounded),
                      onPressed: player.togglePlay,
                    ),
                    IconButton(
                      iconSize: 26,
                      color: Colors.white70,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: player.stop,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
