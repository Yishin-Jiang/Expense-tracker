import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest contains install metadata and valid icon files', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(manifest['short_name'], '好好記帳');
    expect(manifest['lang'], 'zh-TW');
    expect(manifest['start_url'], './#/home');
    expect(manifest['display'], 'standalone');
    expect(manifest['theme_color'], '#1A5C45');

    final icons = manifest['icons']! as List<dynamic>;
    expect(icons, isNotEmpty);
    for (final rawIcon in icons) {
      final icon = rawIcon as Map<String, dynamic>;
      final path = 'web/${icon['src']}';
      expect(File(path).existsSync(), isTrue, reason: '$path should exist');
      expect(File(path).lengthSync(), greaterThan(0));
    }

    expect(File('web/icons/apple-touch-icon-180.png').existsSync(), isTrue);
  });

  test('web shell wires branding, database assets, and offline cache', () {
    final index = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    final worker = File('web/pwa_service_worker.js').readAsStringSync();

    expect(index, contains('apple-mobile-web-app-capable'));
    expect(index, contains('apple-touch-icon-180.png'));
    expect(index, contains('pwa_service_worker.js'));
    expect(index, contains('flutter-first-frame'));
    expect(bootstrap, contains('_flutter.loader.load();'));

    for (final requiredAsset in [
      'main.dart.js',
      'sqlite3.wasm',
      'drift_worker.dart.js',
      'app-icon-192.png',
      'canvaskit.wasm',
      'skwasm.wasm',
    ]) {
      expect(
        worker,
        contains(requiredAsset),
        reason: '$requiredAsset should be available offline',
      );
    }

    expect(worker, contains("request.mode === 'navigate'"));
    expect(worker, contains("fetch(request)"));
    expect(worker, contains("caches.match(request)"));
  });
}
