import 'package:flutter/material.dart';
import 'package:kbuzz/app/app.dart';
import 'package:kbuzz/app/di.dart';
import 'package:kbuzz/core/announce/announcer.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On-disk preferences for user settings (fire-toast hold time, …).
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // No Firebase init — kBuzz runs fully offline / local-only. Drift is the
  // on-disk source of truth (AGENTS.md §0.2 / §6 sync is a later milestone).
  // SystemAnnouncer = on-device TTS + chime for fire alerts (§10.5).
  runApp(
    AppProviders(
      database: AppDatabase(),
      announcer: SystemAnnouncer(),
      prefs: prefs,
      child: const KBuzzApp(),
    ),
  );
}
