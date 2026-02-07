String normalizeMarkdown(String input) {
  var out = input;
  // Remove stray selectable-region context menu divs captured from web.
  out = out.replaceAll(
    RegExp(r'<div class="web-selectable-region-context-menu"[^>]*></div>'),
    '',
  );
  // Unescape common markdown escapes that break image parsing.
  out = out.replaceAllMapped(
    RegExp(r'\\([\\`*_{}\[\]()#+\-.!])'),
    (m) => m[1]!,
  );
  // Fix nested link pattern: ![alt]([url](url)) or with extra trailing ')'.
  out = out.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\(\[([^\]]+)\]\(([^)\s]+)\)\)\)+(?=\s|$)'),
    (m) => '![${m[1]}](${m[3]})',
  );
  // Fix malformed image markdown with an extra trailing ')'.
  out = out.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\(([^)\s]+)\)\)(?=\s|$)'),
    (m) => '![${m[1]}](${m[2]})',
  );
  return out;
}
