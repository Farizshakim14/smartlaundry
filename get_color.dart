import 'dart:io';
import 'package:image/image.dart';

void main() {
  final bytes = File('assets/welcome.png').readAsBytesSync();
  final image = decodeImage(bytes);
  if (image != null) {
    final pixel = image.getPixel(50, 10);
    print('Color at (50, 10): ${pixel.r}, ${pixel.g}, ${pixel.b}');
  } else {
    print('Failed to decode image');
  }
}
