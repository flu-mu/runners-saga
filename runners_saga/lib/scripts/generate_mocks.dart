// Minimal PNG mock generator using the `image` package.
// Run with: dart run runners_saga/lib/scripts/generate_mocks.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// Theme colors (ARGB)
const int kMidnightNavy = 0xFF0B1B2B;
const int kRoyalPlum    = 0xFF2A1E5C;
const int kDeepTeal     = 0xFF0E4C63;
const int kElectricAqua = 0xFF18D2C4;
const int kEmberCoral   = 0xFFFF6B57;
const int kMeadowGreen  = 0xFF30C474;
const int kSurfaceBase  = 0xFF101826;
const int kSurfaceElev  = 0xFF0E1420;
const int kTextHigh     = 0xFFEAF2F6;
const int kDivider      = 0x331C2433;

void main() async {
  final outDir = Directory('assets/images/mocks');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  await _episodeDetails(outDir);
  await _runTargetSheet(outDir);
  await _runScreen(outDir);
  await _postRun(outDir);
  await _logs(outDir);

  stdout.writeln('✅ Mock PNGs created in assets/images/mocks');
}

Future<void> _episodeDetails(Directory dir) async {
  final canvas = img.Image(1170, 2532); // 3x iPhone 13
  // Gradient header
  for (int y = 0; y < 660; y++) {
    final t = y / 660.0;
    final c = _lerpColor(kRoyalPlum, kDeepTeal, t);
    for (int x = 0; x < canvas.width; x++) {
      canvas.setPixel(x, y, _argb(c));
    }
  }
  // Body background
  _fill(canvas, kSurfaceBase, top: 660);
  // Title
  _label(canvas, 60, 120, 'Season 1 · Episode 2', kTextHigh);
  _label(canvas, 60, 200, 'Distraction', kTextHigh, big: true);

  // Tiles
  int top = 760;
  for (final t in ['Duration', 'Tracking', 'Sprints', 'Music']) {
    _card(canvas, 60, top, canvas.width - 120, 180, kSurfaceElev);
    _label(canvas, 100, top + 60, t, kTextHigh);
    top += 220;
  }
  // Download pill
  _pill(canvas, 60, top, canvas.width - 120, 120, kMeadowGreen);
  _label(canvas, 100, top + 36, 'All files cached', kMidnightNavy);
  top += 160;
  // CTA
  _button(canvas, 60, top, canvas.width - 120, 140, kElectricAqua, 'Start Workout');

  File('${dir.path}/01_episode_details.png').writeAsBytesSync(img.encodePng(canvas));
}

Future<void> _runTargetSheet(Directory dir) async {
  final canvas = _sheetBase('Set Duration');
  _label(canvas, 80, 400, 'Distance  •  Time', kTextHigh);
  _progress(canvas, 80, 560, canvas.width - 160, 24, kElectricAqua);
  _chip(canvas, 80, 680, '5.0 min', true);
  _chip(canvas, 280, 680, '7.5 min', false);
  _chip(canvas, 520, 680, '10.0 min', false);
  _button(canvas, 80, 880, canvas.width - 160, 120, kElectricAqua, 'Apply');
  File('${dir.path}/02_target_sheet.png').writeAsBytesSync(img.encodePng(canvas));
}

Future<void> _runScreen(Directory dir) async {
  final canvas = img.Image(1170, 2532);
  _fill(canvas, kSurfaceBase);
  // Header pulse
  _rect(canvas, 0, 0, canvas.width, 16, kEmberCoral);
  // Title
  _label(canvas, 60, 60, 'Distraction', kTextHigh);
  // Stats slab
  _card(canvas, 60, 160, canvas.width - 120, 260, kSurfaceElev);
  _label(canvas, 100, 200, '0.00 km   |   00:09   |   0\'00"/km', kTextHigh);
  // Map panel
  _card(canvas, 60, 460, canvas.width - 120, 900, kSurfaceElev);
  _polyline(canvas, 120, 600, canvas.width - 180, 980, kElectricAqua);
  _marker(canvas, canvas.width - 240, 1200, kMeadowGreen);
  // HUD chip
  _pill(canvas, 60, 1420, 520, 120, kSurfaceElev);
  _label(canvas, 100, 1456, 'Incoming transmission', kTextHigh);
  // Controls
  _outlineButton(canvas, 60, 1600, 420, 140, kElectricAqua, 'Pause');
  _outlineButton(canvas, 540, 1600, canvas.width - 600, 140, kEmberCoral, 'End Run');
  File('${dir.path}/03_run_screen.png').writeAsBytesSync(img.encodePng(canvas));
}

Future<void> _postRun(Directory dir) async {
  final canvas = img.Image(1170, 2532);
  _fill(canvas, kSurfaceBase);
  // Banner
  for (int y = 0; y < 360; y++) {
    final t = y / 360.0;
    final c = _lerpColor(kRoyalPlum, kDeepTeal, t);
    for (int x = 0; x < canvas.width; x++) {
      canvas.setPixel(x, y, _argb(c));
    }
  }
  _label(canvas, 60, 120, 'Episode Complete', kTextHigh, big: true);
  // Metric cards
  int left = 60;
  for (final m in ['10.78 km', '56:30', '5\'14"/km']) {
    _card(canvas, left, 420, 320, 220, kSurfaceElev);
    _label(canvas, left + 40, 500, m, kTextHigh);
    left += 360;
  }
  // Splits
  int top = 720;
  for (int i = 1; i <= 8; i++) {
    _progress(canvas, 60, top, canvas.width - 120, 24, _mix(kElectricAqua, kMeadowGreen, i / 8));
    top += 56;
  }
  File('${dir.path}/04_post_run.png').writeAsBytesSync(img.encodePng(canvas));
}

Future<void> _logs(Directory dir) async {
  final canvas = img.Image(1170, 2532);
  _fill(canvas, kSurfaceBase);
  _label(canvas, 60, 80, 'Workout Logs', kTextHigh, big: true);
  int top = 220;
  for (final row in ['Distraction   10.78 km', 'Jolly Alpha Five Niner   9.68 km']) {
    _card(canvas, 60, top, canvas.width - 120, 180, kSurfaceElev);
    _label(canvas, 100, top + 60, row, kTextHigh);
    top += 220;
  }
  File('${dir.path}/05_workout_logs.png').writeAsBytesSync(img.encodePng(canvas));
}

// --- primitives ------------------------------------------------------------

void _fill(img.Image c, int color, {int top = 0}) {
  for (int y = top; y < c.height; y++) {
    for (int x = 0; x < c.width; x++) {
      c.setPixel(x, y, _argb(color));
    }
  }
}

void _rect(img.Image c, int x, int y, int w, int h, int color) {
  for (int yy = y; yy < y + h; yy++) {
    for (int xx = x; xx < x + w; xx++) {
      c.setPixel(xx, yy, _argb(color));
    }
  }
}

void _card(img.Image c, int x, int y, int w, int h, int color) {
  _rect(c, x, y, w, h, color);
  // simple border lines
  _rect(c, x, y, w, 4, kDivider);
  _rect(c, x, y + h - 4, w, 4, kDivider);
}

void _pill(img.Image c, int x, int y, int w, int h, int color) => _rect(c, x, y, w, h, color);

void _button(img.Image c, int x, int y, int w, int h, int color, String text) {
  _rect(c, x, y, w, h, color);
  _label(c, x + 40, y + h ~/ 2 - 20, text, kMidnightNavy);
}

void _outlineButton(img.Image c, int x, int y, int w, int h, int color, String text) {
  // border
  _rect(c, x, y, w, 4, color);
  _rect(c, x, y + h - 4, w, 4, color);
  _rect(c, x, y, 4, h, color);
  _rect(c, x + w - 4, y, 4, h, color);
  _label(c, x + 40, y + h ~/ 2 - 20, text, color);
}

void _progress(img.Image c, int x, int y, int w, int h, int color) {
  _rect(c, x, y, w, h, kDivider);
  _rect(c, x, y, (w * 0.66).toInt(), h, color);
}

void _chip(img.Image c, int x, int y, String label, bool selected) {
  const w = 160;
  const h = 80;
  _rect(c, x, y, w, h, selected ? kElectricAqua : kDivider);
  _label(c, x + 24, y + 28, label, selected ? kMidnightNavy : kTextHigh);
}

void _marker(img.Image c, int x, int y, int color) {
  _rect(c, x - 16, y - 16, 32, 32, color);
}

void _polyline(img.Image c, int x1, int y1, int x2, int y2, int color) {
  for (int i = 0; i < 400; i++) {
    final t = i / 400.0;
    final x = (x1 + (x2 - x1) * t).toInt();
    final y = (y1 + (y2 - y1) * t + (10 * math.sin(t * math.pi * 2))).toInt();
    if (x >= 0 && x < c.width && y >= 0 && y < c.height) {
      c.setPixel(x, y, _argb(color));
    }
  }
}

void _label(img.Image c, int x, int y, String text, int color, {bool big = false}) {
  final font = big ? img.arial_48 : img.arial_24;
  img.drawString(c, font, x, y, text, color: _argb(color));
}

img.Image _sheetBase(String title) {
  final canvas = img.Image(1170, 1600);
  _fill(canvas, kSurfaceElev);
  _label(canvas, 60, 60, title, kTextHigh, big: true);
  return canvas;
}

int _argb(int color) => img.getColor((color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF, (color >> 24) & 0xFF);

int _lerpColor(int a, int b, double t) {
  final ar = (a >> 16) & 0xFF;
  final ag = (a >> 8) & 0xFF;
  final ab = a & 0xFF;
  final br = (b >> 16) & 0xFF;
  final bg = (b >> 8) & 0xFF;
  final bb = b & 0xFF;
  final r = (ar + ((br - ar) * t)).toInt();
  final g = (ag + ((bg - ag) * t)).toInt();
  final bl = (ab + ((bb - ab) * t)).toInt();
  return (0xFF << 24) | (r << 16) | (g << 8) | bl;
}

int _mix(int a, int b, double t) => _lerpColor(a, b, t);
