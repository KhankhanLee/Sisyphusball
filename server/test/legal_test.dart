import 'package:sisyphus_server/src/http/http_error.dart';
import 'package:sisyphus_server/src/http/legal_pages.dart';
import 'package:test/test.dart';

void main() {
  test('pages are served as HTML with the contact address filled in', () async {
    final pages = LegalPages(directory: 'legal', contactEmail: 'me@example.com');
    for (final name in ['privacy', 'terms']) {
      final res = pages.render(name);
      expect(res.statusCode, 200);
      expect(res.headers['content-type'], startsWith('text/html'));
      final html = await res.readAsString();
      expect(html, contains('mailto:me@example.com'));
      expect(html, isNot(contains('{{contact}}')));
    }
  });

  test('the contact address is HTML-escaped', () async {
    final pages = LegalPages(directory: 'legal', contactEmail: '<script>@x.y');
    final html = await pages.render('privacy').readAsString();
    expect(html, isNot(contains('<script>@')));
    expect(html, contains('&lt;script&gt;@x.y'));
  });

  test('without a contact address the page still makes sense', () async {
    final html = await LegalPages(directory: 'legal', contactEmail: '').render('terms').readAsString();
    expect(html, contains('Pi Browser'));
    expect(html, isNot(contains('mailto:')));
  });

  test('unknown pages and a missing directory are 404s', () {
    expect(() => LegalPages(directory: 'legal', contactEmail: '').render('cookies'), throwsA(isA<HttpError>()));
    expect(() => LegalPages(directory: 'nowhere', contactEmail: '').render('privacy'), throwsA(isA<HttpError>()));
  });
}
