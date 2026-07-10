import 'package:flutter/widgets.dart';

import '../utils/shareable_link_platform.dart';

/// Bootstrap minimo app: nessuna sessione utente globale.
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  captureBootShareableFragment();
}
