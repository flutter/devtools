// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// Parse text containing ANSI color escape codes.
class AnsiParser {
  AnsiParser(String text) : _text = text;

  String _text;
  int _style = StyledText.kNone;
  _AnsiColor? _fg;
  _AnsiColor? _bg;

  Iterable<StyledText> parse() sync* {
    while (true) {
      final packet = _getNextPacket();

      if ((packet.kind == _PacketKind.eos) ||
          (packet.kind == _PacketKind.incomplete)) {
        break;
      }

      // Drop single ESC or Unknown CSI.
      if ((packet.kind == _PacketKind.esc) ||
          (packet.kind == _PacketKind.unknown)) {
        continue;
      }

      if (packet.kind == _PacketKind.text) {
        yield StyledText._from(_withState(packet));
      } else if (packet.kind == _PacketKind.sgr) {
        _processAnsi(packet);
      }
    }
  }

  _TextPacket _getNextPacket() {
    final pkt = _TextPacket(kind: _PacketKind.eos);
    final len = _text.length;
    if (len == 0) {
      return pkt;
    }

    final pos = _text.indexOf('\x1B');
    if (pos == -1) {
      pkt.kind = _PacketKind.text;
      pkt.text = _text;
      _text = '';
      return pkt;
    }

    if (pos > 0) {
      pkt.kind = _PacketKind.text;
      pkt.text = _text.substring(0, pos);
      _text = _text.substring(pos);
      return pkt;
    }

    if (pos == 0) {
      if (len == 1) {
        pkt.kind = _PacketKind.incomplete;
        return pkt;
      }

      final nextChar = _text[1];
      if ((nextChar != '[') && (nextChar != ']')) {
        pkt.kind = _PacketKind.esc;
        pkt.text = _text.substring(0, 1);
        _text = _text.substring(1);
        return pkt;
      }

      if (nextChar == '[') {
        final match = _csiRegex.firstMatch(_text);
        if (match == null) {
          pkt.kind = _PacketKind.incomplete;
          return pkt;
        }

        if (match.groupCount > 4) {
          pkt.kind = _PacketKind.esc;
          pkt.text = _text.substring(0, 1);
          _text = _text.substring(1);
          return pkt;
        }

        final match1 = match.groupCount > 1 ? match.group(1) : null;
        final match3 = match.groupCount > 3 ? match.group(3) : null;
        if (match1 != '' || match3 != 'm') {
          pkt.kind = _PacketKind.unknown;
        } else {
          pkt.kind = _PacketKind.sgr;
        }
        final text = match.groupCount > 2 ? match.group(2) : null;
        if (text != null) {
          pkt.text = text;
        }
        final rpos = match.group(0)!.length;
        _text = _text.substring(rpos);
        return pkt;
      }
    }

    return pkt;
  }

  void _processAnsi(_TextPacket textPacket) {
    final sgrCmds = textPacket.text.split(';');
    int index = 0;
    while (index < sgrCmds.length) {
      final sgrCmdStr = sgrCmds[index++];
      final num = int.tryParse(sgrCmdStr, radix: 10);
      if (num == null || num == 0) {
        _fg = _bg = null;
        _style = StyledText.kNone;
      } else if (num == 1) {
        _style = _style | StyledText.kBold;
      } else if (num == 2) {
        _style = _style | StyledText.kDim;
      } else if (num == 3) {
        _style = _style | StyledText.kItalic;
      } else if (num == 4) {
        _style = _style | StyledText.kUnderline;
      } else if (num == 5) {
        _style = _style | StyledText.kBlink;
      } else if (num == 7) {
        _style = _style | StyledText.kReverse;
      } else if (num == 8) {
        _style = _style | StyledText.kInvisible;
      } else if (num == 9) {
        _style = _style | StyledText.kStrikethrough;
      } else if (num == 22) {
        _style = _style & ~(StyledText.kBold | StyledText.kDim);
      } else if (num == 23) {
        _style = _style & ~StyledText.kItalic;
      } else if (num == 24) {
        _style = _style & ~StyledText.kUnderline;
      } else if (num == 25) {
        _style = _style & ~StyledText.kBlink;
      } else if (num == 27) {
        _style = _style & ~StyledText.kReverse;
      } else if (num == 28) {
        _style = _style & ~StyledText.kInvisible;
      } else if (num == 29) {
        _style = _style & ~StyledText.kStrikethrough;
      } else if (num == 39) {
        _fg = null;
      } else if (num == 49) {
        _bg = null;
      } else if ((num >= 30) && (num < 38)) {
        _fg = _ansiColors[0][(num - 30)];
      } else if ((num >= 40) && (num < 48)) {
        _bg = _ansiColors[0][(num - 40)];
      } else if ((num >= 90) && (num < 98)) {
        _fg = _ansiColors[1][(num - 90)];
      } else if ((num >= 100) && (num < 108)) {
        _bg = _ansiColors[1][(num - 100)];
      } else if (num == 38 || num == 48) {
        if (index < sgrCmds.length) {
          final isForeground = num == 38;
          final modeCmd = sgrCmds[index++];
          if (modeCmd == '5' && index < sgrCmds.length) {
            final paletteIndex = int.tryParse(sgrCmds[index++], radix: 10)!;
            if (paletteIndex >= 0 && paletteIndex <= 255) {
              if (isForeground) {
                _fg = _palette256[paletteIndex];
              } else {
                _bg = _palette256[paletteIndex];
              }
            }
          }
          if (modeCmd == '2' && index + 2 < sgrCmds.length) {
            final r = int.tryParse(sgrCmds[index++], radix: 10);
            final g = int.tryParse(sgrCmds[index++], radix: 10);
            final b = int.tryParse(sgrCmds[index++], radix: 10);
            if (r != null &&
                g != null &&
                b != null &&
                (r >= 0 && r <= 255) &&
                (g >= 0 && g <= 255) &&
                (b >= 0 && b <= 255)) {
              final c = _AnsiColor(rgb: [r, g, b]);
              if (isForeground) {
                _fg = c;
              } else {
                _bg = c;
              }
            }
          }
        }
      }
    }
  }

  _TextWithAttr _withState(_TextPacket packet) =>
      _TextWithAttr(text: packet.text, style: _style, fg: _fg, bg: _bg);
}

const _ansiColors = <List<_AnsiColor>>[
  [
    _AnsiColor(rgb: [0, 0, 0]), // ansi-black
    _AnsiColor(rgb: [187, 0, 0]), // ansi-red
    _AnsiColor(rgb: [0, 187, 0]), // ansi-green
    _AnsiColor(rgb: [187, 187, 0]), // ansi-yellow
    _AnsiColor(rgb: [0, 0, 187]), // ansi-blue
    _AnsiColor(rgb: [187, 0, 187]), // ansi-magenta
    _AnsiColor(rgb: [0, 187, 187]), // ansi-cyan
    _AnsiColor(rgb: [255, 255, 255]), // ansi-white
  ],
  [
    _AnsiColor(rgb: [85, 85, 85]), // ansi-bright-black
    _AnsiColor(rgb: [255, 85, 85]), // ansi-bright-red
    _AnsiColor(rgb: [0, 255, 0]), // ansi-bright-green
    _AnsiColor(rgb: [255, 255, 85]), // ansi-bright-yellow
    _AnsiColor(rgb: [85, 85, 255]), // ansi-bright-blue
    _AnsiColor(rgb: [255, 85, 255]), // ansi-bright-magenta
    _AnsiColor(rgb: [85, 255, 255]), // ansi-bright-cyan
    _AnsiColor(rgb: [255, 255, 255]), // ansi-bright-white
  ],
];

final _palette256 = _createAnsiPalette();

List<_AnsiColor> _createAnsiPalette() {
  final palette = <_AnsiColor>[];

  // ignore: prefer_foreach (clarity)
  for (final colors in _ansiColors) {
    palette.addAll(colors);
  }

  final levels = [0, 95, 135, 175, 215, 255];
  for (var r = 0; r < 6; ++r) {
    for (var g = 0; g < 6; ++g) {
      for (var b = 0; b < 6; ++b) {
        palette.add(_AnsiColor(rgb: [levels[r], levels[g], levels[b]]));
      }
    }
  }

  var greyLevel = 8;
  for (var i = 0; i < 24; ++i, greyLevel += 10) {
    palette.add(_AnsiColor(rgb: [greyLevel, greyLevel, greyLevel]));
  }

  return palette;
}

final _csiRegex = RegExp(
  '^' // beginning of line
  // First attempt
  '(?:' // legal sequence
  '\\x1b\\[' // CSI
  '([\\x3c-\\x3f]?)' // private-mode char
  '([\\d;]*)' // any digits or semicolons
  '([\\x20-\\x2f]?' // an intermediate modifier
  '[\\x40-\\x7e])' // the command
  ')'
  // Second attempt
  '|'
  '(?:' // illegal sequence
  '\\x1b\\[' // CSI
  '[\\x20-\\x7e]*' // anything legal
  '([\\x00-\\x1f:])' // anything illegal
  ')',
);

class _TextWithAttr {
  _TextWithAttr({
    required this.text,
    this.style = StyledText.kNone,
    this.fg,
    this.bg,
  });

  final String text;
  final int style;
  final _AnsiColor? fg;
  final _AnsiColor? bg;
}

class _AnsiColor {
  const _AnsiColor({required this.rgb});

  final List<int> rgb;
}

enum _PacketKind { eos, text, incomplete, esc, unknown, sgr }

class _TextPacket {
  _TextPacket({required this.kind});

  _PacketKind kind;
  String text = '';
  String url = '';
}

/// Chunk of styled text stored in a Dart friendly format.
class StyledText {
  const StyledText(
    this.text, {
    this.textStyle = kNone,
    this.fgColor,
    this.bgColor,
  });

  factory StyledText._from(_TextWithAttr fragment) => StyledText(
    fragment.text,
    textStyle: fragment.style,
    fgColor: fragment.fg?.rgb.toList(),
    bgColor: fragment.bg?.rgb.toList(),
  );

  static const kNone = 0;
  static const kBold = 1;
  static const kDim = 2;
  static const kItalic = 4;
  static const kUnderline = 8;
  static const kStrikethrough = 16;
  static const kBlink = 32;
  static const kReverse = 64;
  static const kInvisible = 128;

  final String text;
  final int textStyle;
  final List<int>? fgColor;
  final List<int>? bgColor;

  bool get bold => (textStyle & kBold) == kBold;
  bool get dim => (textStyle & kDim) == kDim;
  bool get italic => (textStyle & kItalic) == kItalic;
  bool get underline => (textStyle & kUnderline) == kUnderline;
  bool get strikethrough => (textStyle & kStrikethrough) == kStrikethrough;
  bool get blink => (textStyle & kBlink) == kBlink;
  bool get reverse => (textStyle & kReverse) == kReverse;
  bool get invisible => (textStyle & kInvisible) == kInvisible;

  bool get hasStyling => textStyle != 0 || fgColor != null || bgColor != null;

  String get describeStyle {
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    String color(List<int> rgb) => '${hex(rgb[0])}${hex(rgb[2])}${hex(rgb[2])}';

    return [
      if (bgColor != null) 'background #${color(bgColor!)}',
      if (fgColor != null) 'color #${color(fgColor!)}',
      if (bold) 'bold',
      if (dim) 'dim',
      if (italic) 'italic',
      if (underline) 'underline',
      if (strikethrough) 'strikethrough',
      if (blink) 'blink',
      if (reverse) 'reverse',
      if (invisible) 'invisible',
    ].join(', ');
  }
}
