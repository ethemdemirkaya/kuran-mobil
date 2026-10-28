import 'package:flutter/material.dart';

import '../../config.dart';
import '../../data/settings.dart';
import '../../main.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            const Text('Ayarlar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppConfig.besmele,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'Amasya', fontSize: settings.arabicSize, height: 1.9),
                  ),
                  if (settings.showMeal)
                    Text(
                      'Rahmân ve rahîm olan Allah’ın adıyla',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: settings.mealSize),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Label('Arapça yazı boyutu'),
            Slider(
              min: 22,
              max: 48,
              divisions: 13,
              value: settings.arabicSize,
              label: settings.arabicSize.round().toString(),
              onChanged: (v) => settings.arabicSize = v,
            ),
            _Label('Meal yazı boyutu'),
            Slider(
              min: 14,
              max: 30,
              divisions: 16,
              value: settings.mealSize,
              label: settings.mealSize.round().toString(),
              onChanged: (v) => settings.mealSize = v,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Türkçe meali göster', style: TextStyle(fontSize: 17)),
              value: settings.showMeal,
              onChanged: (v) => settings.showMeal = v,
            ),
            if (settings.showMeal) ...[
              _Label('Meal'),
              RadioGroup<String>(
                groupValue: settings.mealSource,
                onChanged: (v) => settings.mealSource = v!,
                child: Column(
                  children: [
                    for (final m in AppConfig.meals)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: m.id,
                        title: Text(m.name, style: const TextStyle(fontSize: 16.5)),
                      ),
                  ],
                ),
              ),
              if (!settings.meal.isDiyanet)
                Text(
                  'Sesli meal Diyanet mealini okur; bu meal seçiliyken mealde kelime boyanmaz.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                ),
            ],
            const Divider(height: 28),
            _Label('Ne okunsun?'),
            const SizedBox(height: 8),
            SegmentedButton<AudioMode>(
              showSelectedIcon: false,
              segments: [
                for (final m in AudioMode.values)
                  ButtonSegment(value: m, label: Text(m.label, style: const TextStyle(fontSize: 14))),
              ],
              selected: {settings.audioMode},
              onSelectionChanged: (s) => settings.audioMode = s.first,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Arapça: ${settings.reciter.name} · Meal: ${AppConfig.mealReaderName}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
              ),
            ),
            const Divider(height: 28),
            _Label('Kelime takibi'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Okunan kelimeyi boya', style: TextStyle(fontSize: 17)),
              value: settings.wordHighlight,
              onChanged: (v) => settings.wordHighlight = v,
            ),
            const Divider(height: 28),
            _Label('Arapça okuyan hafız'),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                "▶ ile Fâtiha'nın başını dinleyip sesini tanıyabilirsiniz. "
                'Quran.com hafızlarında kelimeler tam yerinde boyanır.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
              ),
            ),
            const _ReciterList(),
            const SizedBox(height: 16),
            _Label('Okuma hızı'),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0.75, label: Text('Yavaş')),
                ButtonSegment(value: 1.0, label: Text('Normal')),
                ButtonSegment(value: 1.25, label: Text('Hızlı')),
              ],
              selected: {settings.speed},
              onSelectionChanged: (s) => settings.speed = s.first,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sure bitince sonrakine geç', style: TextStyle(fontSize: 17)),
              value: settings.autoNext,
              onChanged: (v) => settings.autoNext = v,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dinlerken ekranı açık tut', style: TextStyle(fontSize: 17)),
              value: settings.keepScreenOn,
              onChanged: (v) => settings.keepScreenOn = v,
            ),
            const Divider(height: 28),
            _Label('Görünüm'),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Açık'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Koyu'), icon: Icon(Icons.dark_mode_rounded)),
                ButtonSegment(value: ThemeMode.system, label: Text('Otomatik')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.themeMode = s.first,
            ),
            const SizedBox(height: 24),
            Text(
              "Metin ve meal: Diyanet İşleri Başkanlığı Açık Kaynak Kur'an API.",
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReciterList extends StatelessWidget {
  const _ReciterList();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final player = scope.player;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => RadioGroup<int>(
        groupValue: settings.arabicReciter,
        onChanged: (v) => settings.arabicReciter = v!,
        child: Column(
          children: [
            for (final r in AppConfig.reciters)
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: r.id,
                title: Text(r.name, style: const TextStyle(fontSize: 16.5)),
                subtitle: Text(
                  switch (r.source) {
                    ReciterSource.diyanet => 'Diyanet · kelimeler tahmini',
                    ReciterSource.everyAyah => 'EveryAyah · kelimeler tahmini',
                    ReciterSource.quranCom => 'Quran.com · tam kelime takibi',
                    ReciterSource.archive => 'archive.org · kelime takibi (hizalanmış)',
                  },
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                secondary: IconButton(
                  tooltip: 'Dinle',
                  iconSize: 32,
                  color: scheme.primary,
                  icon: Icon(player.previewing == r.id
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_outline_rounded),
                  onPressed: () => player.previewReciter(r.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600));
}
