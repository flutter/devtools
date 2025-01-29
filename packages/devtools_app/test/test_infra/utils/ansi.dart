// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

class AnsiWriter {
  static const _escape = '\x1B[';

  int? _foreground;
  int? _background;

  /// Sets the pen color to the rgb value between 0.0..1.0.
  void rgb({num r = 1.0, num g = 1.0, num b = 1.0, bool bg = false}) {
    xterm(
      (r.clamp(0.0, 1.0) * 5).toInt() * 36 +
          (g.clamp(0.0, 1.0) * 5).toInt() * 6 +
          (b.clamp(0.0, 1.0) * 5).toInt() +
          16,
      bg: bg,
    );
  }

  /// Sets the pen color to a grey scale value between 0.0 and 1.0.
  void gray({num level = 1.0, bool bg = false}) {
    xterm(232 + (level.clamp(0.0, 1.0) * 23).round(), bg: bg);
  }

  void white({bool bg = false, bool bold = false}) {
    _standardColor(7, bold, bg);
  }

  void _standardColor(int color, bool bold, bool bg) {
    xterm(color + (bold ? 8 : 0), bg: bg);
  }

  /// Directly index the xterm 256 color palette.
  void xterm(int color, {bool bg = false}) {
    final c =
        color < 0
            ? 0
            : color > 255
            ? 255
            : color;

    if (bg) {
      _background = c;
    } else {
      _foreground = c;
    }
  }

  /// Write the [message] with the pen's current settings.
  String write(Object message) {
    final pen = StringBuffer();
    if (_foreground != null) {
      pen.write('${_escape}38;5;${_foreground}m');
    }
    if (_background != null) {
      pen.write('${_escape}48;5;${_background}m');
    }

    const normal = '${_escape}0m';

    return '$pen$message$normal';
  }

  /// Resets the pen's attributes.
  void reset() {
    _background = null;
    _foreground = null;
  }
}
