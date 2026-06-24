import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

Future<void> bootstrapSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
