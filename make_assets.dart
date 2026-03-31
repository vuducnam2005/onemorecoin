import 'dart:io';
import 'dart:math';
import 'package:image/image.dart';

void main() {
  final imagePath = 'assets/images/app_icon.png';
  final File file = File(imagePath);
  if (!file.existsSync()) {
    print('Cannot find assets/images/app_icon.png');
    return;
  }
  
  final imageBytes = file.readAsBytesSync();
  Image? originalImage = decodeImage(imageBytes);

  if (originalImage != null) {
     int width = originalImage.width;
     int height = originalImage.height;
     
     // 1. Crop the original image to remove the phone background (approx 70% in center)
     int cropSize = (width * 0.70).toInt(); 
     int startX = (width - cropSize) ~/ 2;
     int startY = (height - cropSize) ~/ 2;
     
     Image cropped = copyCrop(originalImage, x: startX, y: startY, width: cropSize, height: cropSize);
     File('assets/images/app_icon_cropped.png').writeAsBytesSync(encodePng(cropped));
     print('1. Cropped app_icon.png to app_icon_cropped.png');

     // 2. Make it a transparent circle for the splash screen
     int cWidth = cropped.width;
     int cHeight = cropped.height;
     int centerX = cWidth ~/ 2;
     int centerY = cHeight ~/ 2;
     int radius = (min(cWidth, cHeight) ~/ 2) - 10; // Padding to avoid clipping the white stroke

     for (int y = 0; y < cHeight; y++) {
       for (int x = 0; x < cWidth; x++) {
         double dx = (x - centerX).toDouble();
         double dy = (y - centerY).toDouble();
         if (sqrt(dx * dx + dy * dy) > radius) {
            // Set alpha to 0 for transparency
            final pixel = cropped.getPixel(x, y);
            pixel.a = 0; 
         }
       }
     }
     
     File('assets/images/logo_splash.png').writeAsBytesSync(encodePng(cropped));
     print('2. Created transparent circular logo_splash.png');
     print('\nYou can now run:');
     print('  flutter pub run flutter_launcher_icons');
     print('  flutter pub run flutter_native_splash:create');
  } else {
     print('Failed to decode image');
  }
}
