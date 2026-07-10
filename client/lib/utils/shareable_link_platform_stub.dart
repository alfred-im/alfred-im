/// Cattura il fragment all'avvio (no-op fuori web).
void captureBootShareableFragment() {}

String? readShareableFragment() => null;

void clearShareableFragment() {}

Stream<String?> watchShareableFragment() => const Stream.empty();
