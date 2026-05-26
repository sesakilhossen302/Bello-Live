import 'dart:io';

void main() {
  final source = File('assets/svga/gamebannerBlue svga');
  final target = File('assets/svga/gamebannerBlue.svga');
  
  if (source.existsSync()) {
    source.copySync(target.path);
    print('Successfully copied "gamebannerBlue svga" to "gamebannerBlue.svga"!');
  } else {
    print('Source file "assets/svga/gamebannerBlue svga" not found.');
  }
}
