import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'tab_shell.dart';
import 'theme/app_theme.dart';
import '../features/home/domain/providers.dart';

class CheXiaoJiApp extends ConsumerWidget {
  const CheXiaoJiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: '车小记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 250),
      home: const AppTabShell(),
    );
  }
}
