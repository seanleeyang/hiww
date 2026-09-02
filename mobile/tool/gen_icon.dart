// Generates the Hiww app-icon source PNGs. Run: `dart run tool/gen_icon.dart`.
// Output feeds flutter_launcher_icons / flutter_native_splash (see pubspec.yaml).
import 'dart:io';
import 'package:image/image.dart' as img;

const size = 1024;
final coral = img.ColorRgb8(0xE1, 0x52, 0x3A);
final white = img.ColorRgb8(0xFF, 0xFF, 0xFF);

/// Draws the "H." mark centred on [canvas] in [color].
void drawMark(img.Image canvas, img.Color color) {
  // "H": two legs + a crossbar, sized against a 1024 grid.
  const legW = 150;
  const gap = 210; // inner gap between legs
  const glyphH = 470;
  const barH = 150;
  final cx = size ~/ 2 - 60; // leave room for the dot on the right
  final top = (size - glyphH) ~/ 2;

  final leftX = cx - gap ~/ 2 - legW;
  final rightX = cx + gap ~/ 2;

  img.fillRect(canvas,
      x1: leftX, y1: top, x2: leftX + legW, y2: top + glyphH, color: color, radius: 20);
  img.fillRect(canvas,
      x1: rightX, y1: top, x2: rightX + legW, y2: top + glyphH, color: color, radius: 20);
  img.fillRect(canvas,
      x1: leftX,
      y1: top + (glyphH - barH) ~/ 2,
      x2: rightX + legW,
      y2: top + (glyphH + barH) ~/ 2,
      color: color,
      radius: 12);

  // The dot.
  img.fillCircle(canvas,
      x: rightX + legW + 130, y: top + glyphH - 75, radius: 78, color: color);
}

void write(String path, img.Image image) {
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $path');
}

void main() {
  // Full-bleed icon: coral field, white mark.
  final icon = img.Image(width: size, height: size);
  img.fill(icon, color: coral);
  drawMark(icon, white);
  write('assets/icon/icon.png', icon);

  // Adaptive foreground: transparent, white mark inside the safe zone.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  final inner = img.Image(width: size, height: size, numChannels: 4);
  img.fill(inner, color: img.ColorRgba8(0, 0, 0, 0));
  drawMark(inner, white);
  final scaled = img.copyResize(inner, width: (size * 0.62).round());
  img.compositeImage(fg, scaled,
      dstX: (size - scaled.width) ~/ 2, dstY: (size - scaled.height) ~/ 2);
  write('assets/icon/icon_foreground.png', fg);

  // Splash mark: transparent, coral mark (shown on the warm splash background).
  final splash = img.Image(width: size, height: size, numChannels: 4);
  img.fill(splash, color: img.ColorRgba8(0, 0, 0, 0));
  drawMark(splash, coral);
  write('assets/icon/splash.png', splash);
}
