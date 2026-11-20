/// Makes editor-generated HTML safe for flutter_html's TextStyle conversion.
///
/// flutter_html maps every `font-feature-settings` declaration to
/// dart:ui's `FontFeature`, whose tag must be exactly four ASCII characters.
/// CMS content sometimes contains human-readable values (`normal`, `liga`,
/// etc.), which triggers a layout-time assertion. Removing the declaration is
/// safer than trying to guess which values are valid: the surrounding text
/// still renders with the app's own typography.
String sanitizeHtmlForFlutter(String html) {
  // Drop inline style attributes that carry the offending declaration. This
  // keeps the rest of the attribute list intact and avoids leaving a broken
  // quote behind when the declaration is the only one in the attribute.
  var cleaned = html.replaceAllMapped(
    RegExp(
      r'''(<\s*[a-zA-Z][^>]*?)\s+style\s*=\s*(["'])([^"']*font-feature-settings[^"']*)\2([^>]*>)''',
      caseSensitive: false,
      multiLine: true,
    ),
    (match) => '${match.group(1)}${match.group(4)}',
  );

  // Remove the same declaration from <style> blocks and from any attribute
  // the first pass could not match (for example, nested quote characters).
  cleaned = cleaned.replaceAll(
    RegExp(
      r'font-feature-settings\s*:\s*[^;}]+;?',
      caseSensitive: false,
    ),
    '',
  );

  return cleaned;
}
