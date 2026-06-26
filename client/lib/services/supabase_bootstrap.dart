import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

Future<void> bootstrapSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await waitForSupabaseSessionReady();
}

/// supabase_flutter avvia [SupabaseAuth.recoverSession] in background dopo
/// [Supabase.initialize] senza attendere. Le prime RPC possono restare appese
/// finché il client auth non ha finito l'idratazione (tipico su web).
Future<void> waitForSupabaseSessionReady() async {
  if (_isFlutterTest) return;

  final auth = supabase.auth;

  // Primo frame: recoverSession interno parte in parallelo a runApp.
  await Future<void>.delayed(const Duration(milliseconds: 50));

  if (auth.currentSession == null) return;

  try {
    await auth.refreshSession().timeout(const Duration(seconds: 10));
  } on TimeoutException {
    // Prosegui: la sessione può comunque diventare utilizzabile subito dopo.
  } catch (_) {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

bool get _isFlutterTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

SupabaseClient get supabase => Supabase.instance.client;

void disposeRealtimeChannel(RealtimeChannel? channel) {
  if (channel != null) {
    supabase.removeChannel(channel);
  }
}
