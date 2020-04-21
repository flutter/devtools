// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// ansi_up is an library that parses text containing ANSI color escape
/// codes.

class AnsiUp {
  AnsiUp() {
    _setupPalettes();
    bold = false;
  }

  String _text;
  bool bold;
  List<List<AnsiUpColor>> ansiColors;
  List<AnsiUpColor> palette256;
  AnsiUpColor fg;
  AnsiUpColor bg;
  RegExp _csiRegex;

  void _setupPalettes() {
    ansiColors = [
      [
        AnsiUpColor(rgb: [0, 0, 0], className: 'ansi-black'),
        AnsiUpColor(rgb: [187, 0, 0], className: 'ansi-red'),
        AnsiUpColor(rgb: [0, 187, 0], className: 'ansi-green'),
        AnsiUpColor(rgb: [187, 187, 0], className: 'ansi-yellow'),
        AnsiUpColor(rgb: [0, 0, 187], className: 'ansi-blue'),
        AnsiUpColor(rgb: [187, 0, 187], className: 'ansi-magenta'),
        AnsiUpColor(rgb: [0, 187, 187], className: 'ansi-cyan'),
        AnsiUpColor(rgb: [255, 255, 255], className: 'ansi-white'),
      ],
      [
        AnsiUpColor(rgb: [85, 85, 85], className: 'ansi-bright-black'),
        AnsiUpColor(rgb: [255, 85, 85], className: 'ansi-bright-red'),
        AnsiUpColor(rgb: [0, 255, 0], className: 'ansi-bright-green'),
        AnsiUpColor(rgb: [255, 255, 85], className: 'ansi-bright-yellow'),
        AnsiUpColor(rgb: [85, 85, 255], className: 'ansi-bright-blue'),
        AnsiUpColor(rgb: [255, 85, 255], className: 'ansi-bright-magenta'),
        AnsiUpColor(rgb: [85, 255, 255], className: 'ansi-bright-cyan'),
        AnsiUpColor(rgb: [255, 255, 255], className: 'ansi-bright-white'),
      ]
    ];
    palette256 = [];
    ansiColors.forEach(palette256.addAll);
    final levels = [0, 95, 135, 175, 215, 255];
    for (var r = 0; r < 6; ++r) {
      for (var g = 0; g < 6; ++g) {
        for (var b = 0; b < 6; ++b) {
          palette256.add(AnsiUpColor(
              rgb: [levels[r], levels[g], levels[b]], className: 'truecolor'));
        }
      }
    }
    var greyLevel = 8;
    for (var i = 0; i < 24; ++i, greyLevel += 10) {
      palette256.add(AnsiUpColor(
          rgb: [greyLevel, greyLevel, greyLevel], className: 'truecolor'));
    }
  }

  TextPacket _getNextPacket() {
    final pkt = TextPacket(kind: PacketKind.EOS, text: '', url: '');
    final len = _text.length;
    if (len == 0) {
      return pkt;
    }
    final pos = _text.indexOf('\x1B');
    if (pos == -1) {
      pkt.kind = PacketKind.Text;
      pkt.text = _text;
      _text = '';
      return pkt;
    }
    if (pos > 0) {
      pkt.kind = PacketKind.Text;
      pkt.text = _text.substring(0, pos);
      _text = _text.substring(pos);
      return pkt;
    }
    if (pos == 0) {
      if (len == 1) {
        pkt.kind = PacketKind.Incomplete;
        return pkt;
      }
      final String nextChar = _text[1];
      if ((nextChar != '[') && (nextChar != ']')) {
        pkt.kind = PacketKind.ESC;
        pkt.text = _text.substring(0, 1);
        _text = _text.substring(1);
        return pkt;
      }
      if (nextChar == '[') {
        _csiRegex ??= cleanAndConvertToRegex('\n                        '
            '^                           # beginning of line'
            '\n                                                    #'
            '\n                                                    '
            '# First attempt'
            '\n                        '
            '(?:                         # legal sequence'
            '\n                          '
            '\\x1b\\[                      # CSI'
            '\n                          '
            '([\\x3c-\\x3f]?)              # private-mode char'
            '\n                          '
            '([\\d;]*)                    # any digits or semicolons'
            '\n                          '
            '([\\x20-\\x2f]?               # an intermediate modifier'
            '\n                          '
            '[\\x40-\\x7e])                # the command'
            '\n                        )\n                        '
            '|                           # alternate (second attempt)'
            '\n                        '
            '(?:                         # illegal sequence'
            '\n                          '
            '\\x1b\\[                      # CSI'
            '\n                          '
            '[\\x20-\\x7e]*                # anything legal'
            '\n                          '
            '([\\x00-\\x1f:])              # anything illegal'
            '\n                        )\n                    ');
        final match = _csiRegex.firstMatch(_text);
        if (match == null) {
          pkt.kind = PacketKind.Incomplete;
          return pkt;
        }
        if (match.groupCount > 4) {
          pkt.kind = PacketKind.ESC;
          pkt.text = _text.substring(0, 1);
          _text = _text.substring(1);
          return pkt;
        }
        final match1 = match.groupCount > 1 ? match.group(1) : null;
        final match3 = match.groupCount > 3 ? match.group(3) : null;
        if (match1 != '' || match3 != 'm') {
          pkt.kind = PacketKind.Unknown;
        } else {
          pkt.kind = PacketKind.SGR;
        }
        pkt.text = match.groupCount > 2 ? match.group(2) : null;
        final rpos = match.group(0).length;
        _text = _text.substring(rpos);
        return pkt;
      }
      // TODO: Convert the JS code (below) that identifies OS commands.
      //if (next_char == ']') {
      //  if (len < 4) {
      //    pkt.kind = PacketKind.Incomplete;
      //    return pkt;
      //  }
      //  if ((this._buffer.charAt(2) != '8')
      //      || (this._buffer.charAt(3) != ';')) {
      //    pkt.kind = PacketKind.ESC;
      //    pkt.text = this._buffer.slice(0, 1);
      //    this._buffer = this._buffer.slice(1);
      //    return pkt;
      //  }
      //  if (!this._osc_st) {
      //    this._osc_st = rgxG(__makeTemplateObject(["\n                        (?:                         # legal sequence\n                          (\u001B\\)                    # ESC                           |                           # alternate\n                          (\u0007)                      # BEL (what xterm did)\n                        )\n                        |                           # alternate (second attempt)\n                        (                           # illegal sequence\n                          [\0-\u0006]                 # anything illegal\n                          |                           # alternate\n                          [\b-\u001A]                 # anything illegal\n                          |                           # alternate\n                          [\u001C-\u001F]                 # anything illegal\n                        )\n                    "], ["\n                        (?:                         # legal sequence\n                          (\\x1b\\\\)                    # ESC \\\n                          |                           # alternate\n                          (\\x07)                      # BEL (what xterm did)\n                        )\n                        |                           # alternate (second attempt)\n                        (                           # illegal sequence\n                          [\\x00-\\x06]                 # anything illegal\n                          |                           # alternate\n                          [\\x08-\\x1a]                 # anything illegal\n                          |                           # alternate\n                          [\\x1c-\\x1f]                 # anything illegal\n                        )\n                    "]));
      //  }
      //  this._osc_st.lastIndex = 0;
      //  {
      //    var match_1 = this._osc_st.exec(this._buffer);
      //    if (match_1 === null) {
      //      pkt.kind = PacketKind.Incomplete;
      //      return pkt;
      //    }
      //    if (match_1[3]) {
      //      pkt.kind = PacketKind.ESC;
      //      pkt.text = this._buffer.slice(0, 1);
      //      this._buffer = this._buffer.slice(1);
      //      return pkt;
      //    }
      //  }
      //  {
      //    var match_2 = this._osc_st.exec(this._buffer);
      //    if (match_2 === null) {
      //      pkt.kind = PacketKind.Incomplete;
      //      return pkt;
      //    }
      //    if (match_2[3]) {
      //      pkt.kind = PacketKind.ESC;
      //      pkt.text = this._buffer.slice(0, 1);
      //      this._buffer = this._buffer.slice(1);
      //      return pkt;
      //    }
      //  }
      //  if (!this._osc_regex) {
      //    this._osc_regex = rgx(__makeTemplateObject(["\n                        ^                           # beginning of line\n                                                    #\n                        \u001B]8;                    # OSC Hyperlink\n                        [ -:<-~]*       # params (excluding ;)\n                        ;                           # end of params\n                        ([!-~]{0,512})        # URL capture\n                        (?:                         # ST\n                          (?:\u001B\\)                  # ESC                           |                           # alternate\n                          (?:\u0007)                    # BEL (what xterm did)\n                        )\n                        ([!-~]+)              # TEXT capture\n                        \u001B]8;;                   # OSC Hyperlink End\n                        (?:                         # ST\n                          (?:\u001B\\)                  # ESC                           |                           # alternate\n                          (?:\u0007)                    # BEL (what xterm did)\n                        )\n                    "], ["\n                        ^                           # beginning of line\n                                                    #\n                        \\x1b\\]8;                    # OSC Hyperlink\n                        [\\x20-\\x3a\\x3c-\\x7e]*       # params (excluding ;)\n                        ;                           # end of params\n                        ([\\x21-\\x7e]{0,512})        # URL capture\n                        (?:                         # ST\n                          (?:\\x1b\\\\)                  # ESC \\\n                          |                           # alternate\n                          (?:\\x07)                    # BEL (what xterm did)\n                        )\n                        ([\\x21-\\x7e]+)              # TEXT capture\n                        \\x1b\\]8;;                   # OSC Hyperlink End\n                        (?:                         # ST\n                          (?:\\x1b\\\\)                  # ESC \\\n                          |                           # alternate\n                          (?:\\x07)                    # BEL (what xterm did)\n                        )\n                    "]));
      //  }
      //  var match = this._buffer.match(this._osc_regex);
      //  if (match === null) {
      //    pkt.kind = PacketKind.ESC;
      //    pkt.text = this._buffer.slice(0, 1);
      //    this._buffer = this._buffer.slice(1);
      //    return pkt;
      //  }
      //  pkt.kind = PacketKind.OSCURL;
      //  pkt.url = match[1];
      //  pkt.text = match[2];
      //  var rpos = match[0].length;
      //  this._buffer = this._buffer.slice(rpos);
      //  return pkt;
      //}
    }
    return pkt;
  }

  void _processAnsi(TextPacket textPacket) {
    final sgrCmds = textPacket.text.split(';');
    int index = 0;
    while (index < sgrCmds.length) {
      final sgrCmdStr = sgrCmds[index++];
      final num = int.tryParse(sgrCmdStr, radix: 10);
      if (num == null || num == 0) {
        fg = bg = null;
        bold = false;
      } else if (num == 1) {
        bold = true;
      } else if (num == 22) {
        bold = false;
      } else if (num == 39) {
        fg = null;
      } else if (num == 49) {
        bg = null;
      } else if ((num >= 30) && (num < 38)) {
        fg = ansiColors[0][(num - 30)];
      } else if ((num >= 40) && (num < 48)) {
        bg = ansiColors[0][(num - 40)];
      } else if ((num >= 90) && (num < 98)) {
        fg = ansiColors[1][(num - 90)];
      } else if ((num >= 100) && (num < 108)) {
        bg = ansiColors[1][(num - 100)];
      } else if (num == 38 || num == 48) {
        if (index < sgrCmds.length) {
          final isForeground = num == 38;
          final modeCmd = sgrCmds[index++];
          if (modeCmd == '5' && index < sgrCmds.length) {
            final paletteIndex = int.tryParse(sgrCmds[index++], radix: 10);
            if (paletteIndex >= 0 && paletteIndex <= 255) {
              if (isForeground) {
                fg = palette256[paletteIndex];
              } else {
                bg = palette256[paletteIndex];
              }
            }
          }
          if (modeCmd == '2' && index + 2 < sgrCmds.length) {
            final r = int.tryParse(sgrCmds[index++], radix: 10);
            final g = int.tryParse(sgrCmds[index++], radix: 10);
            final b = int.tryParse(sgrCmds[index++], radix: 10);
            if ((r >= 0 && r <= 255) &&
                (g >= 0 && g <= 255) &&
                (b >= 0 && b <= 255)) {
              final c = AnsiUpColor(rgb: [r, g, b], className: 'truecolor');
              if (isForeground) {
                fg = c;
              } else {
                bg = c;
              }
            }
          }
        }
      }
    }
  }

  TextWithAttr _withState(TextPacket packet) {
    return TextWithAttr(bold: bold, fg: fg, bg: bg, text: packet.text);
  }
}

class TextWithAttr {
  TextWithAttr({this.fg, this.bg, this.bold, this.text});

  final AnsiUpColor fg;
  final AnsiUpColor bg;
  final bool bold;
  final String text;
}

class AnsiUpColor {
  AnsiUpColor({this.rgb, this.className});

  final List<int> rgb;
  final String className;
}

enum PacketKind {
  EOS,
  Text,
  Incomplete,
  ESC,
  Unknown,
  SGR,
  OSCURL,
}

class TextPacket {
  TextPacket({this.kind, this.text, this.url});

  PacketKind kind;
  String text;
  final String url;
}

String _colorToCss(List/*<int>*/ rgb) => 'rgb(${rgb.join(',')})';

// Removes comments and spaces/newlines from a regex string that were present
// for readability.
RegExp cleanAndConvertToRegex(String regexText) {
  final RegExp spacesAndComments =
      RegExp(r'^\s+|\s+\n|\s*#[\s\S]*?\n|\n', multiLine: true);
  return RegExp(regexText.replaceAll(spacesAndComments, ''));
}

/// Chunk of styled text stored in a Dart friendly format.
class StyledText {
  const StyledText(
    this.text, {
    this.fgColor,
    this.bgColor,
    this.bold = false,
    this.url,
  });

  factory StyledText.from(TextWithAttr fragment) {
    return StyledText(
      fragment.text,
      fgColor: fragment?.fg?.rgb?.toList(),
      bgColor: fragment?.bg?.rgb?.toList(),
      bold: fragment.bold == true,
    );
  }

  final String text;
  final List<int> fgColor;
  final List<int> bgColor;
  final bool bold;
  final String url;

  String get style {
    if (fgColor == null && bgColor == null && !bold) {
      return '';
    }
    return <String>[
      if (bgColor != null) 'background-color: ${_colorToCss(bgColor)}',
      if (fgColor != null) 'color: ${_colorToCss(fgColor)}',
      if (bold) 'font-weight: bold',
    ].join(';');
  }
}

/// Main entrypoint to call to parse ansi color escaped text.
///
/// An instance of ansiUp is passed in to maintain text styling state across
/// multiple invocations of this method.
Iterable<StyledText> decodeAnsiColorEscapeCodes(
    String text, AnsiUp ansiUp) sync* {
  ansiUp._text = text;
  while (true) {
    final packet = ansiUp._getNextPacket();

    if ((packet.kind == PacketKind.EOS) ||
        (packet.kind == PacketKind.Incomplete)) {
      break;
    }
    // Drop single ESC or Unknown CSI.
    if ((packet.kind == PacketKind.ESC) ||
        (packet.kind == PacketKind.Unknown)) {
      continue;
    }

    if (packet.kind == PacketKind.Text) {
      yield StyledText.from(ansiUp._withState(packet));
    } else if (packet.kind == PacketKind.SGR) {
      ansiUp._processAnsi(packet);
    } else if (packet.kind == PacketKind.OSCURL) {
      final url = packet.url;
      if (url.startsWith('http:') || url.startsWith('https:')) {
        yield StyledText(packet.text, url: url);
      } else {
        yield StyledText(packet.text); // Not a safe url to include.
      }
    }
  }
}
