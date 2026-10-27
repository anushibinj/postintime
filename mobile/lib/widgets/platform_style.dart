import 'package:flutter/material.dart';

import '../models/models.dart';

const _colors = {
  Platform.linkedin: Color(0xFF0A66C2),
  Platform.instagram: Color(0xFFE4405F),
  Platform.whatsapp: Color(0xFF25D366),
  Platform.youtube: Color(0xFFFF0000),
  Platform.x: Color(0xFF111111),
  Platform.facebook: Color(0xFF1877F2),
  Platform.threads: Color(0xFF111111),
};

const _glyphs = {
  Platform.linkedin: 'in',
  Platform.instagram: 'IG',
  Platform.whatsapp: 'WA',
  Platform.youtube: 'YT',
  Platform.x: 'X',
  Platform.facebook: 'f',
  Platform.threads: '@',
};

Color platformColor(Platform platform) => _colors[platform]!;

String platformGlyph(Platform platform) => _glyphs[platform]!;
