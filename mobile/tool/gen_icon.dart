// Generates the Hiww app-icon/splash/in-app-mark PNGs from the master logo
// art (assets/icon/logo_source.png — the two-shape "h" mark on Linen).
// Run: `dart run tool/gen_icon.dart`, then regenerate the platform icons
// with `dart run flutter_launcher_icons` and
// `dart run flutter_native_splash:create` (see pubspec.yaml).
import 'dart:io';
import 'package:image/image.dart' as img;

const canvasSize = 1024;

final linen = img.ColorRgb8(0xFA, 0xE8, 0xDD);
final tangelo = img.ColorRgba8(0xFB, 0x4D, 0x00, 255); // light-theme orange
final chocolate = img.ColorRgba8(0x49, 0x26, 0x1D, 255); // light-theme dark shape
final tangeloDark = img.ColorRgba8(0xFF, 0x86, 0x59, 255); // dark-theme orange
final onSurfaceDark = img.ColorRgba8(0xF7, 0xEC, 0xE4, 255); // dark-theme dark shape
final white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 255);

double _dist2(num r, num g, num b, img.Color c) {
  final dr = r - c.r, dg = g - c.g, db = b - c.b;
  return (dr * dr + dg * dg + db * db).toDouble();
}

/// Recolors the source mark onto a transparent canvas of the same size,
/// classifying each non-background pixel as the orange shape or the dark
/// shape (whichever sampled brand color it's closer to) and filling it with
/// [orange]/[dark], with edge alpha graded by distance from the background
/// so anti-aliasing stays smooth.
img.Image _extractMark(img.Image source, img.Color bg, img.Color orange, img.Color dark) {
  final out = img.Image(width: source.width, height: source.height, numChannels: 4);
  const lowT = 12.0 * 12.0 * 3, highT = 40.0 * 40.0 * 3;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      final dBg = _dist2(p.r, p.g, p.b, bg);
      double alpha;
      if (dBg <= lowT) {
        alpha = 0;
      } else if (dBg >= highT) {
        alpha = 255;
      } else {
        alpha = 255 * (dBg - lowT) / (highT - lowT);
      }
      if (alpha <= 0) {
        out.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        continue;
      }
      final fill = _dist2(p.r, p.g, p.b, tangelo) <= _dist2(p.r, p.g, p.b, chocolate) ? orange : dark;
      out.setPixel(x, y, img.ColorRgba8(fill.r.toInt(), fill.g.toInt(), fill.b.toInt(), alpha.round()));
    }
  }
  return out;
}

img.Image _tightCrop(img.Image mask) {
  var minX = mask.width, minY = mask.height, maxX = 0, maxY = 0;
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      if (mask.getPixel(x, y).a > 40) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return img.copyCrop(mask, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
}

/// Composites [mark] onto [canvas], scaled so its width is [widthFraction]
/// of the canvas, centered.
void _placeScaled(img.Image canvas, img.Image mark, double widthFraction) {
  final scale = (canvas.width * widthFraction) / mark.width;
  final scaled = img.copyResize(mark,
      width: (mark.width * scale).round(), height: (mark.height * scale).round());
  img.compositeImage(canvas, scaled,
      dstX: (canvas.width - scaled.width) ~/ 2, dstY: (canvas.height - scaled.height) ~/ 2);
}

void _write(String path, img.Image image) {
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $path');
}

void main() {
  final source = img.decodeImage(File('assets/icon/logo_source.png').readAsBytesSync())!;
  final bg = source.getPixel(5, 5);

  final lightMark = _tightCrop(_extractMark(source, bg, tangelo, chocolate));
  final darkMark = _tightCrop(_extractMark(source, bg, tangeloDark, onSurfaceDark));

  // Full-bleed icon: Linen field, mark near-full-size (iOS/web static icon).
  final icon = img.Image(width: canvasSize, height: canvasSize);
  img.fill(icon, color: linen);
  _placeScaled(icon, lightMark, 0.72);
  _write('assets/icon/icon.png', icon);

  // Adaptive foreground: transparent, mark inside Android's safe zone.
  // adaptive_icon_background is Linen (pubspec.yaml) so the orange shape
  // stays visible against it.
  final fg = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  _placeScaled(fg, lightMark, 0.5);
  _write('assets/icon/icon_foreground.png', fg);

  // Splash mark: single-tone white, not the two-tone mark — the splash
  // background is now solid Tangelo (see pubspec.yaml/splash_screen.dart,
  // the Wise-style launch screen), and a white mark is what reads against
  // a saturated brand-color field, the same way Wise's launch screen uses
  // one flat dark mark on their flat brand-green background.
  final splashMask = _tightCrop(_extractMark(source, bg, white, white));
  final splash = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  _placeScaled(splash, splashMask, 0.6);
  _write('assets/icon/splash.png', splash);

  // In-app brand mark next to the "Hiww." wordmark (see ui/brand_mark.dart)
  // — separate light/dark renders since it sits on the app's own surface
  // colors rather than a fixed icon/splash background.
  _write('assets/images/hiww_mark.png', lightMark);
  _write('assets/images/hiww_mark_dark.png', darkMark);

  // Same white mark as assets/icon/splash.png, but as a tight, unscaled
  // crop for the in-app splash screen widget to size explicitly (see
  // features/shell/splash_screen.dart) rather than pre-placed on a canvas.
  _write('assets/images/hiww_mark_white.png', splashMask);
}
