// lib/ui/page/settings/accountSettings/privacyAndSafety/mutedWordsPage.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/state/settingsState.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

class MutedWordsPage extends StatefulWidget {
  const MutedWordsPage({Key? key}) : super(key: key);

  @override
  State<MutedWordsPage> createState() => _MutedWordsPageState();
}

class _MutedWordsPageState extends State<MutedWordsPage> {
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<SettingsState>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add(SettingsState st) async {
    final word = _input.text.trim().toLowerCase();
    if (word.isEmpty) return;
    final words = st.getList('muted_words');
    if (words.contains(word)) {
      settingsSnack(context, 'That word is already muted.');
      return;
    }
    _input.clear();
    await st.setValue('muted_words', [...words, word]);
  }

  Future<void> _remove(SettingsState st, String word) async {
    final words = st.getList('muted_words')..remove(word);
    await st.setValue('muted_words', words);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsState>();
    final words = st.getList('muted_words');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SettingsAppBar(title: 'Muted words'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(st),
                    decoration: const InputDecoration(
                      hintText: 'Add a word or phrase',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.plus, color: AppColor.primary),
                  onPressed: () => _add(st),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: words.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'You have no muted words. Words you add here are hidden from your notifications.',
                        textAlign: TextAlign.center,
                        style: kSettingSubtitle,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: words.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) => ListTile(
                      contentPadding: kSettingPadding,
                      title: Text(words[i], style: kSettingTitle),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.trash2,
                            color: AppColor.darkGrey),
                        onPressed: () => _remove(st, words[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
