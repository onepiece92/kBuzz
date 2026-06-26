import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/router.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';

/// Root widget: a router-driven [MaterialApp] whose neon (dark) / pastel (light)
/// theme follows the user's [SettingsCubit.themeMode]. The cubit is provided
/// above this widget (see `app/di.dart`), so flipping the theme in Profile
/// rebuilds only the [MaterialApp].
class KBuzzApp extends StatelessWidget {
  const KBuzzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (SettingsState a, SettingsState b) =>
          a.themeMode != b.themeMode,
      builder: (BuildContext context, SettingsState settings) =>
          MaterialApp.router(
        title: 'kBuzz',
        debugShowCheckedModeBanner: false,
        theme: buildKBuzzTheme(Brightness.light),
        darkTheme: buildKBuzzTheme(Brightness.dark),
        themeMode: settings.themeMode,
        routerConfig: appRouter,
      ),
    );
  }
}
