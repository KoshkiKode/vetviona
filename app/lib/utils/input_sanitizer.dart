/// Input sanitization helpers for all user-supplied and externally-imported
/// text that enters the application.
///
/// Goals:
///   1. Remove null bytes and C0/C1 control characters that can cause display
///      glitches, mislead parsers, or create visual spoofing opportunities.
///   2. Enforce sensible per-field length limits to prevent memory exhaustion
///      from crafted sync payloads or malicious GEDCOM files.
///
/// What we deliberately do NOT do:
///   - HTML/script escaping — Flutter widgets render text as plain text,
///     not HTML, so XSS is not applicable.
///   - SQL escaping — SQLite access uses parameterised queries throughout.
library;

class InputSanitizer {
  InputSanitizer._();

  // ── Field-length caps ──────────────────────────────────────────────────────

  /// Maximum length for typical short fields (name, place, occupation …).
  static const maxShortField = 500;

  /// Maximum length for medium free-text fields (notes, source citation …).
  static const maxMediumField = 5000;

  /// Maximum length for passwords / usernames (local auth).
  static const maxAuthField = 256;

  // ── Core helper ───────────────────────────────────────────────────────────

  /// Sanitises [text] by:
  ///   1. Removing C0 control characters (U+0000–U+001F) except for
  ///      horizontal tab (U+0009), newline (U+000A) and carriage return
  ///      (U+000D), which are legitimate in multi-line text fields.
  ///   2. Removing the DEL character (U+007F).
  ///   3. Removing C1 control characters (U+0080–U+009F).
  ///   4. Truncating to [maxLength] code units.
  ///
  /// Returns `null` when [text] is `null`.
  static String? sanitize(String? text, {int maxLength = maxShortField}) {
    if (text == null) return null;
    // Remove null bytes, C0 controls (except TAB/LF/CR), DEL, and C1 controls.
    final cleaned = text.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\x80-\x9F]'),
      '',
    );
    if (cleaned.length <= maxLength) return cleaned;
    return cleaned.substring(0, maxLength);
  }

  /// Convenience variant for fields that must never be null (returns `''`
  /// instead of `null` when the input is null).
  static String sanitizeRequired(
    String? text, {
    int maxLength = maxShortField,
  }) =>
      sanitize(text, maxLength: maxLength) ?? '';

  // ── Typed convenience wrappers ─────────────────────────────────────────────

  /// Sanitise a person's name (short field, required).
  static String name(String? v) =>
      sanitizeRequired(v, maxLength: maxShortField);

  /// Sanitise a place name, occupation, nationality, etc. (short, optional).
  static String? shortField(String? v) =>
      sanitize(v, maxLength: maxShortField);

  /// Sanitise a notes / free-text area (medium length, optional).
  static String? mediumField(String? v) =>
      sanitize(v, maxLength: maxMediumField);

  /// Sanitise a local-auth username or password (short, keeps all printable
  /// chars — users should be able to use any printable character).
  static String authField(String? v) =>
      sanitizeRequired(v, maxLength: maxAuthField);
}
