import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/documents/browser/browser_article.dart';

void main() {
  test('upgrades the legacy Kickstarter URL preserving its article location', () {
    final url = Uri.parse(
      'http://fourhourworkweek.com/2012/12/18/hacking-kickstarter-how-to-raise-100000-in-10-days-includes-successful-templates-e-mails-etc/?ref=harrys#comments',
    );
    final secure = secureArticleUrl(url);
    expect(secure.scheme, 'https');
    expect(secure.host, url.host);
    expect(secure.path, url.path);
    expect(secure.query, url.query);
    expect(secure.fragment, url.fragment);
    expect(secure.port, 443);
    expect(secure.toString(), isNot(contains(':80')));
  });

  test('preserves HTTPS and non-web links and handles explicit ports', () {
    for (final raw in [
      'https://example.org/a',
      'nx-docs://document/1',
      'mailto:hello@example.org',
    ]) {
      final url = Uri.parse(raw);
      expect(secureArticleUrl(url), url);
    }
    expect(
      secureArticleUrl(Uri.parse('http://example.org:80/a')).toString(),
      'https://example.org/a',
    );
    expect(secureArticleUrl(Uri.parse('http://example.org:8080/a')).port, 8080);
  });
}
