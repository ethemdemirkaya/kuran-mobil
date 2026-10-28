import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'audio/player_controller.dart';
import 'data/quran_repository.dart';
import 'data/settings.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ethemdemirkaya.kuran_mobil.audio',
    androidNotificationChannelName: "Kur'an Tilaveti",
    androidNotificationOngoing: true,
  );
  final settings = await Settings.load();
  final repo = QuranRepository();
  final player = PlayerController(repo, settings);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(AppScope(repo: repo, settings: settings, player: player, child: const KuranApp()));
}

/// Uygulama servislerine erişim.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repo,
    required this.settings,
    required this.player,
    required super.child,
  });

  final QuranRepository repo;
  final Settings settings;
  final PlayerController player;

  static AppScope of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

class KuranApp extends StatelessWidget {
  const KuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: "Kur'an-ı Kerim",
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        home: const HomeScreen(),
      ),
    );
  }
}
