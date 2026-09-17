// One-off: derives the admin console's favicon + sidebar/login mark from
// the same generated icon_foreground.png (see gen_icon.dart) so the admin
// console matches the app's new logo instead of the old unrelated default
// Vite favicon. Run: `dart run tool/gen_admin_favicon.dart`.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final source =
      img.decodeImage(File('assets/icon/icon_foreground.png').readAsBytesSync())!;

  final mark = img.copyResize(source, width: 256, height: 256);
  File('../admin-web/src/assets/hiww-mark.png').writeAsBytesSync(img.encodePng(mark));

  final favicon = img.copyResize(source, width: 64, height: 64);
  File('../admin-web/public/favicon.png').writeAsBytesSync(img.encodePng(favicon));

  stdout.writeln('wrote ../admin-web/public/hiww-mark.png and favicon.png');
}
