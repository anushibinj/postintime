import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter tests draw text with the "Ahem" font, where every glyph is a full square, so text is
/// about twice as wide as on a device and layouts overflow in tests only. Loading the real Roboto
/// and icon fonts from the Flutter SDK makes layout checks match what phones show.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final fonts = '$root/bin/cache/artifacts/material_fonts';
    await _load('Roboto', fonts, ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Light.ttf']);
    await _load('MaterialIcons', fonts, ['MaterialIcons-Regular.otf']);
  }
  await testMain();
}

Future<void> _load(String family, String directory, List<String> files) async {
  final loader = FontLoader(family);
  var any = false;
  for (final name in files) {
    final file = File('$directory/$name');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
      any = true;
    }
  }
  if (any) {
    await loader.load();
  }
}
