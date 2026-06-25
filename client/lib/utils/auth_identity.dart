/// Mapping username ↔ identificatore GoTrue (email interna, mai mostrata in UI).
class AuthIdentity {
  AuthIdentity._();

  /// Dominio riservato Supabase Auth — non è un indirizzo federato né visibile all'utente.
  static const internalEmailDomain = 'users.alfred.internal';

  static final usernamePattern = RegExp(r'^[a-z0-9_]{3,32}$');

  static String normalizeUsername(String input) => input.trim().toLowerCase();

  static bool isValidUsername(String username) =>
      usernamePattern.hasMatch(username);

  static String? validateUsername(String input) {
    final normalized = normalizeUsername(input);
    if (normalized.isEmpty) return 'Inserisci un username';
    if (!isValidUsername(normalized)) {
      return 'Username: 3–32 caratteri, solo lettere minuscole, numeri e _';
    }
    return null;
  }

  static String internalAuthEmail(String username) {
    final normalized = normalizeUsername(username);
    return '$normalized@$internalEmailDomain';
  }

  /// Estrae lo username dall'email interna della sessione Supabase.
  static String? usernameFromAuthEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    final suffix = '@$internalEmailDomain';
    if (email.endsWith(suffix)) {
      return email.substring(0, email.length - suffix.length);
    }
    return null;
  }
}
