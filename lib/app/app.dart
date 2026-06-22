import 'package:flutter/material.dart';
import 'package:kbuzz/app/router.dart';
import 'package:kbuzz/app/theme.dart';

/// Root widget: a router-driven [MaterialApp] on the dark KDS theme.
class KBuzzApp extends StatelessWidget {
  const KBuzzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'kBuzz',
      debugShowCheckedModeBanner: false,
      theme: buildKBuzzTheme(),
      routerConfig: appRouter,
    );
  }
}
