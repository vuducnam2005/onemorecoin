import 'package:flutter/material.dart';

class CustomIcon extends StatelessWidget {
  final String? iconPath;
  final double? size;
  final Color? color;

  const CustomIcon({Key? key, this.iconPath, this.size, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (iconPath == null || iconPath!.isEmpty) {
      return Icon(Icons.category_outlined, size: size ?? 24.0, color: color ?? Colors.grey);
    }
    if (iconPath!.startsWith('assets/')) {
      return Image.asset(iconPath!, width: size, height: size);
    }
    int? codePoint = int.tryParse(iconPath!);
    if (codePoint != null) {
      return Icon(
        IconData(codePoint, fontFamily: 'MaterialIcons'),
        size: size ?? 24.0,
        color: color ?? Colors.orange,
      );
    }
    return Image.asset('assets/images/default.png', width: size, height: size);
  }
}
