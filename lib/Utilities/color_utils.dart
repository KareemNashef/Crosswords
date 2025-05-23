// Flutter imports
import 'package:flutter/material.dart';

// Converts a Color object to a HEX string (e.g., #RRGGBB)
String colorToHexString(Color color) {
  // ignore: deprecated_member_use
  return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

// Converts a HEX string (e.g., #RRGGBB) to a Color object
Color hexStringToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff'); // Add alpha if missing (assume opaque)
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return Colors.black; // Fallback color in case of error
  }
}