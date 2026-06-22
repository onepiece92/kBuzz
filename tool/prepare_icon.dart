// One-off: turn the supplied `kBuzz.png` (cream squircle on a solid-black
// canvas, pre-rounded corners) into clean launcher-icon sources:
//
//   assets/icon/app_icon.png            full-bleed cream square (iOS/macOS/web)
//   assets/icon/app_icon_foreground.png cream squircle tile on transparency,
//                                       centred at 70% (Android adaptive layer)
//
// It crops to the squircle, then flood-fills the black corners from the border
// (to cream for the opaque icon; to cream-tinted transparency for the
// foreground, so resizing leaves no dark halo over the orange background).
//
// Run from the project root:  dart run tool/prepare_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const int kOut = 1024;
// The cream tile nearly fills the foreground PNG; flutter_launcher_icons then
// applies its own 16% adaptive inset, landing the tile at ~0.95 × 0.68 ≈ 0.65
// of the final canvas — a cream squircle framed by the orange background.
const double kForegroundScale = 0.95;

void main() {
  final img.Image src = img.decodePng(File('kBuzz.png').readAsBytesSync())!;

  // 1. Bounding box of the bright cream squircle (excludes the black margin).
  int minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      if (img.getLuminance(src.getPixel(x, y)) > 170) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  final img.Image tile = img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );

  // 2. Sample the cream just inside the top edge (above the artwork).
  final img.Pixel cream = tile.getPixel(tile.width ~/ 2, (tile.height * 0.04).round());
  final int cr = cream.r.toInt(), cg = cream.g.toInt(), cb = cream.b.toInt();

  // 3a. Opaque cream full-bleed → app_icon.png.
  final img.Image creamTile = img.Image.from(tile);
  _floodFromBorder(creamTile, (img.Image im, int x, int y) {
    im.setPixelRgba(x, y, cr, cg, cb, 255);
  });
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(
    img.copyResize(creamTile,
        width: kOut, height: kOut, interpolation: img.Interpolation.average),
  ));

  // 3b. Cream tile on transparency → Android adaptive foreground.
  final img.Image alphaTile = tile.convert(numChannels: 4);
  _floodFromBorder(alphaTile, (img.Image im, int x, int y) {
    // Keep the RGB cream so resampling blends cream (no dark halo), alpha 0.
    im.setPixelRgba(x, y, cr, cg, cb, 0);
  });
  final int fg = (kOut * kForegroundScale).round();
  final img.Image scaled = img.copyResize(alphaTile,
      width: fg, height: fg, interpolation: img.Interpolation.average);
  final img.Image fgOut = img.Image(width: kOut, height: kOut, numChannels: 4);
  final int off = (kOut - fg) ~/ 2;
  img.compositeImage(fgOut, scaled, dstX: off, dstY: off);
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(fgOut));

  String hex(int v) => v.toRadixString(16).padLeft(2, '0');
  // ignore: avoid_print
  print('cream=#${hex(cr)}${hex(cg)}${hex(cb)} '
      'bbox=($minX,$minY)-($maxX,$maxY) tile=${tile.width}x${tile.height}');
}

/// Flood-fill the dark region connected to the image border, calling [fill] on
/// each dark pixel. Stops at bright (cream) pixels, so the interior artwork —
/// enclosed by the cream squircle — is never touched.
void _floodFromBorder(
  img.Image im,
  void Function(img.Image im, int x, int y) fill,
) {
  final int w = im.width, h = im.height;
  final List<bool> visited = List<bool>.filled(w * h, false);
  final List<int> stack = <int>[];
  void seed(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final int i = y * w + x;
    if (!visited[i]) stack.add(i);
  }

  for (int x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (int y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }
  while (stack.isNotEmpty) {
    final int i = stack.removeLast();
    if (visited[i]) continue;
    visited[i] = true;
    final int x = i % w, y = i ~/ w;
    if (img.getLuminance(im.getPixel(x, y)) >= 200) continue; // cream edge
    fill(im, x, y);
    seed(x + 1, y);
    seed(x - 1, y);
    seed(x, y + 1);
    seed(x, y - 1);
  }
}
