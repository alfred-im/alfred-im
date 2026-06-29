import 'package:flutter/widgets.dart';

/// Bootstrap minimo app: nessuna sessione utente globale.
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
}
