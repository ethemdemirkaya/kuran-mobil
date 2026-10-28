import 'package:flutter/material.dart';

import '../data/models.dart';
import '../main.dart';
import 'surah_screen.dart';
import 'theme.dart';
import 'widgets/mini_player.dart';
import 'widgets/settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Surah>> _surahs = AppScope.of(context).repo.surahs();
  String _query = '';

  void _open(Surah s, {int verse = 1}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SurahScreen(surah: s, initialVerse: verse),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Kur'an-ı Kerim"),
          actions: [
            IconButton(
              tooltip: 'Ayarlar',
              iconSize: 28,
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => showSettingsSheet(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: FutureBuilder<List<Surah>>(
          future: _surahs,
          builder: (context, snap) {
            final surahs = snap.data;
            if (surahs == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                ListenableBuilder(
                  listenable: scope.settings,
                  builder: (context, _) {
                    final last = scope.settings.lastRead;
                    if (last == null) return const SizedBox.shrink();
                    final s = surahs[last.$1 - 1];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _ContinueCard(
                        surah: s,
                        verse: last.$2,
                        onTap: () => _open(s, verse: last.$2),
                      ),
                    );
                  },
                ),
                const TabBar(
                  labelStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: TextStyle(fontSize: 17),
                  tabs: [
                    Tab(text: 'Sureler'),
                    Tab(text: 'Cüzler'),
                    Tab(text: 'Kaydedilenler'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SurahList(
                        surahs: surahs,
                        query: _query,
                        onQuery: (q) => setState(() => _query = q),
                        onOpen: _open,
                      ),
                      _JuzList(surahs: surahs, onOpen: _open),
                      _BookmarkList(surahs: surahs, onOpen: _open),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: MiniPlayer(onOpen: _open),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.surah, required this.verse, required this.onTap});

  final Surah surah;
  final int verse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.green, AppColors.greenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KALDIĞIN YERDEN DEVAM ET',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12.5,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${surah.name} Suresi',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$verse. ayet · ${juzOf(surah.id, verse)}. cüz',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  surah.arabicName,
                  style: const TextStyle(fontFamily: 'Amasya', fontSize: 30, color: Color(0xFFF1DDAF)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList({
    required this.surahs,
    required this.query,
    required this.onQuery,
    required this.onOpen,
  });

  final List<Surah> surahs;
  final String query;
  final ValueChanged<String> onQuery;
  final void Function(Surah) onOpen;

  @override
  Widget build(BuildContext context) {
    final q = normalizeTr(query);
    final list = q.isEmpty
        ? surahs
        : surahs
            .where((s) => normalizeTr(s.name).contains(q) || '${s.id}' == q)
            .toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: list.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: onQuery,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Sure ara (örn. Yâsîn, 36)',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          );
        }
        final s = list[i - 1];
        return _SurahTile(surah: s, onTap: () => onOpen(s));
      },
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah, required this.onTap});

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            VerseBadge(surah.id, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(surah.name,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${surah.verseCount} ayet · ${surah.juz}. cüz · sayfa ${surah.firstPage}',
                    style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              surah.arabicName,
              style: TextStyle(fontFamily: 'Amasya', fontSize: 26, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.surahs, required this.onOpen});

  final List<Surah> surahs;
  final void Function(Surah, {int verse}) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: juzStarts.length,
      itemBuilder: (context, i) {
        final (sid, verse) = juzStarts[i];
        final s = surahs[sid - 1];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpen(s, verse: verse),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800, color: scheme.primary)),
                  const Text('Cüz', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${s.name} $verse',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
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

class _BookmarkList extends StatelessWidget {
  const _BookmarkList({required this.surahs, required this.onOpen});

  final List<Surah> surahs;
  final void Function(Surah, {int verse}) onOpen;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final list = settings.bookmarks;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 56, color: scheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz kaydedilmiş ayet yok.\nAyetin yanındaki işaret simgesine dokunarak kaydedebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final b = list[i];
            final s = surahs[b.surah - 1];
            return Dismissible(
              key: ValueKey(b.key),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => settings.removeBookmark(b),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
              ),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  onTap: () => onOpen(s, verse: b.verse),
                  title: Text('${s.name} · ${b.verse}. ayet',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(b.snippet, style: const TextStyle(fontSize: 15)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
