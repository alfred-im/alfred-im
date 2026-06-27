/// Logica pura per l'aggancio al fondo (ListView [reverse: true]).
abstract final class ConversationScrollAnchor {
  /// Distanza dal fondo entro cui si considera la vista agganciata.
  static const double defaultThreshold = 48;

  /// Con [reverse: true], il fondo corrisponde a [ScrollPosition.pixels] ≈ 0.
  static bool isAttached(double pixels, {double threshold = defaultThreshold}) {
    return pixels <= threshold;
  }

  /// Nuovi messaggi in coda: scroll automatico se già agganciato o se c'è un invio proprio.
  static bool shouldAutoScrollOnAppend({
    required bool wasAttached,
    required bool hasOutgoingInBatch,
  }) {
    return wasAttached || hasOutgoingInBatch;
  }
}
