import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'http_error.dart';

/// The Privacy Policy and Terms of Service, served at /privacy and /terms.
///
/// The pages are HTML templates in [directory]; `{{contact}}` is filled in
/// from configuration so the address is not baked into the repository.
class LegalPages {
  LegalPages({required String directory, required String contactEmail})
      : _pages = {
          for (final name in const ['privacy', 'terms'])
            if (File('$directory/$name.html').existsSync())
              name: File('$directory/$name.html')
                  .readAsStringSync()
                  .replaceAll('{{contact}}', _contactHtml(contactEmail)),
        };

  final Map<String, String> _pages;

  Response render(String name) {
    final html = _pages[name];
    if (html == null) throw HttpError(404, 'not found');
    return Response.ok(html, headers: {'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=3600'});
  }

  static String _contactHtml(String email) {
    if (email.isEmpty) return 'Questions or deletion requests: use the contact listed on the Sisyphusball page in the Pi Browser.';
    final safe = htmlEscape.convert(email);
    return 'Questions or deletion requests: <a href="mailto:$safe">$safe</a>';
  }
}
