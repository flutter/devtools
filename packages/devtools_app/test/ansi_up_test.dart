// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansi_up/ansi_up.dart';
import 'package:ansicolor/ansicolor.dart';
import 'package:test/test.dart';

void main() {
  group('ansi_up', () {
    test('test standard colors', () {
      final pen = AnsiPen();
      final sb = StringBuffer();
      // Test the 16 color defaults.
      for (int c = 0; c < 16; c++) {
        pen
          ..reset()
          ..white(bold: true)
          ..xterm(c, bg: true);
        sb.write(pen('$c '));
        pen
          ..reset()
          ..xterm(c);
        sb.write(pen(' $c '));
        if (c == 7 || c == 15) {
          sb.writeln();
        }
      }

      // Test a few custom colors.
      for (int r = 0; r < 6; r += 3) {
        sb.writeln();
        for (int g = 0; g < 6; g += 3) {
          for (int b = 0; b < 6; b += 3) {
            final c = r * 36 + g * 6 + b + 16;
            pen
              ..reset()
              ..rgb(r: r / 5, g: g / 5, b: b / 5, bg: true)
              ..white(bold: true);
            sb.write(pen(' $c '));
            pen
              ..reset()
              ..rgb(r: r / 5, g: g / 5, b: b / 5);
            sb.write(pen(' $c '));
          }
          sb.writeln();
        }
      }

      for (int c = 0; c < 24; c++) {
        if (0 == c % 8) {
          sb.writeln();
        }
        pen
          ..reset()
          ..gray(level: c / 23, bg: true)
          ..white(bold: true);
        sb.write(pen(' ${c + 232} '));
        pen
          ..reset()
          ..gray(level: c / 23);
        sb.write(pen(' ${c + 232} '));
      }

      final output = StringBuffer();
      for (var entry in decodeAnsiColorEscapeCodes(sb.toString(), AnsiUp())) {
        if (entry.style.isNotEmpty) {
          output.write("<span style='${entry.style}'>${entry.text}</span>");
        } else {
          output.write(entry.text);
          // TODO: Note that we are not handling links yet.
        }
      }
      expect(
          output.toString(),
          equals(
              '<span style=\'background-color: rgb(0,0,0);color: rgb(255,255,255)\'>0 </span><span style=\'color: rgb(0,0,0)\'> 0 </span><span style=\'background-color: rgb(187,0,0);color: rgb(255,255,255)\'>1 </span><span style=\'color: rgb(187,0,0)\'> 1 </span><span style=\'background-color: rgb(0,187,0);color: rgb(255,255,255)\'>2 </span><span style=\'color: rgb(0,187,0)\'> 2 </span><span style=\'background-color: rgb(187,187,0);color: rgb(255,255,255)\'>3 </span><span style=\'color: rgb(187,187,0)\'> 3 </span><span style=\'background-color: rgb(0,0,187);color: rgb(255,255,255)\'>4 </span><span style=\'color: rgb(0,0,187)\'> 4 </span><span style=\'background-color: rgb(187,0,187);color: rgb(255,255,255)\'>5 </span><span style=\'color: rgb(187,0,187)\'> 5 </span><span style=\'background-color: rgb(0,187,187);color: rgb(255,255,255)\'>6 </span><span style=\'color: rgb(0,187,187)\'> 6 </span><span style=\'background-color: rgb(255,255,255);color: rgb(255,255,255)\'>7 </span><span style=\'color: rgb(255,255,255)\'> 7 </span>\n'
              '<span style=\'background-color: rgb(85,85,85);color: rgb(255,255,255)\'>8 </span><span style=\'color: rgb(85,85,85)\'> 8 </span><span style=\'background-color: rgb(255,85,85);color: rgb(255,255,255)\'>9 </span><span style=\'color: rgb(255,85,85)\'> 9 </span><span style=\'background-color: rgb(0,255,0);color: rgb(255,255,255)\'>10 </span><span style=\'color: rgb(0,255,0)\'> 10 </span><span style=\'background-color: rgb(255,255,85);color: rgb(255,255,255)\'>11 </span><span style=\'color: rgb(255,255,85)\'> 11 </span><span style=\'background-color: rgb(85,85,255);color: rgb(255,255,255)\'>12 </span><span style=\'color: rgb(85,85,255)\'> 12 </span><span style=\'background-color: rgb(255,85,255);color: rgb(255,255,255)\'>13 </span><span style=\'color: rgb(255,85,255)\'> 13 </span><span style=\'background-color: rgb(85,255,255);color: rgb(255,255,255)\'>14 </span><span style=\'color: rgb(85,255,255)\'> 14 </span><span style=\'background-color: rgb(255,255,255);color: rgb(255,255,255)\'>15 </span><span style=\'color: rgb(255,255,255)\'> 15 </span>\n'
              '\n'
              '<span style=\'background-color: rgb(0,0,0);color: rgb(255,255,255)\'> 16 </span><span style=\'color: rgb(0,0,0)\'> 16 </span><span style=\'background-color: rgb(0,0,175);color: rgb(255,255,255)\'> 19 </span><span style=\'color: rgb(0,0,175)\'> 19 </span>\n'
              '<span style=\'background-color: rgb(0,175,0);color: rgb(255,255,255)\'> 34 </span><span style=\'color: rgb(0,175,0)\'> 34 </span><span style=\'background-color: rgb(0,175,175);color: rgb(255,255,255)\'> 37 </span><span style=\'color: rgb(0,175,175)\'> 37 </span>\n'
              '\n'
              '<span style=\'background-color: rgb(175,0,0);color: rgb(255,255,255)\'> 124 </span><span style=\'color: rgb(175,0,0)\'> 124 </span><span style=\'background-color: rgb(175,0,175);color: rgb(255,255,255)\'> 127 </span><span style=\'color: rgb(175,0,175)\'> 127 </span>\n'
              '<span style=\'background-color: rgb(175,175,0);color: rgb(255,255,255)\'> 142 </span><span style=\'color: rgb(175,175,0)\'> 142 </span><span style=\'background-color: rgb(175,175,175);color: rgb(255,255,255)\'> 145 </span><span style=\'color: rgb(175,175,175)\'> 145 </span>\n'
              '\n'
              '<span style=\'background-color: rgb(8,8,8);color: rgb(255,255,255)\'> 232 </span><span style=\'color: rgb(8,8,8)\'> 232 </span><span style=\'background-color: rgb(18,18,18);color: rgb(255,255,255)\'> 233 </span><span style=\'color: rgb(18,18,18)\'> 233 </span><span style=\'background-color: rgb(28,28,28);color: rgb(255,255,255)\'> 234 </span><span style=\'color: rgb(28,28,28)\'> 234 </span><span style=\'background-color: rgb(38,38,38);color: rgb(255,255,255)\'> 235 </span><span style=\'color: rgb(38,38,38)\'> 235 </span><span style=\'background-color: rgb(48,48,48);color: rgb(255,255,255)\'> 236 </span><span style=\'color: rgb(48,48,48)\'> 236 </span><span style=\'background-color: rgb(58,58,58);color: rgb(255,255,255)\'> 237 </span><span style=\'color: rgb(58,58,58)\'> 237 </span><span style=\'background-color: rgb(68,68,68);color: rgb(255,255,255)\'> 238 </span><span style=\'color: rgb(68,68,68)\'> 238 </span><span style=\'background-color: rgb(78,78,78);color: rgb(255,255,255)\'> 239 </span><span style=\'color: rgb(78,78,78)\'> 239 </span>\n'
              '<span style=\'background-color: rgb(88,88,88);color: rgb(255,255,255)\'> 240 </span><span style=\'color: rgb(88,88,88)\'> 240 </span><span style=\'background-color: rgb(98,98,98);color: rgb(255,255,255)\'> 241 </span><span style=\'color: rgb(98,98,98)\'> 241 </span><span style=\'background-color: rgb(108,108,108);color: rgb(255,255,255)\'> 242 </span><span style=\'color: rgb(108,108,108)\'> 242 </span><span style=\'background-color: rgb(118,118,118);color: rgb(255,255,255)\'> 243 </span><span style=\'color: rgb(118,118,118)\'> 243 </span><span style=\'background-color: rgb(128,128,128);color: rgb(255,255,255)\'> 244 </span><span style=\'color: rgb(128,128,128)\'> 244 </span><span style=\'background-color: rgb(138,138,138);color: rgb(255,255,255)\'> 245 </span><span style=\'color: rgb(138,138,138)\'> 245 </span><span style=\'background-color: rgb(148,148,148);color: rgb(255,255,255)\'> 246 </span><span style=\'color: rgb(148,148,148)\'> 246 </span><span style=\'background-color: rgb(158,158,158);color: rgb(255,255,255)\'> 247 </span><span style=\'color: rgb(158,158,158)\'> 247 </span>\n'
              '<span style=\'background-color: rgb(168,168,168);color: rgb(255,255,255)\'> 248 </span><span style=\'color: rgb(168,168,168)\'> 248 </span><span style=\'background-color: rgb(178,178,178);color: rgb(255,255,255)\'> 249 </span><span style=\'color: rgb(178,178,178)\'> 249 </span><span style=\'background-color: rgb(188,188,188);color: rgb(255,255,255)\'> 250 </span><span style=\'color: rgb(188,188,188)\'> 250 </span><span style=\'background-color: rgb(198,198,198);color: rgb(255,255,255)\'> 251 </span><span style=\'color: rgb(198,198,198)\'> 251 </span><span style=\'background-color: rgb(208,208,208);color: rgb(255,255,255)\'> 252 </span><span style=\'color: rgb(208,208,208)\'> 252 </span><span style=\'background-color: rgb(218,218,218);color: rgb(255,255,255)\'> 253 </span><span style=\'color: rgb(218,218,218)\'> 253 </span><span style=\'background-color: rgb(228,228,228);color: rgb(255,255,255)\'> 254 </span><span style=\'color: rgb(228,228,228)\'> 254 </span><span style=\'background-color: rgb(238,238,238);color: rgb(255,255,255)\'> 255 </span><span style=\'color: rgb(238,238,238)\'> 255 </span>'));
    });
  });
}
