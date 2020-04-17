// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// ansi_up is an library that parses text containing ANSI color escape
/// codes.

class AnsiUp {
  String version, _buffer;
  bool bold;
  List<List<AnsiUpColor>> ansiColors;
  List<AnsiUpColor> palette256;
  AnsiUpColor fg;
  AnsiUpColor bg;
  RegExp _csiRegex;

  // ignore: sort_constructors_first
  AnsiUp() {
    version = '4.0.3';
    _setupPalettes();
    bold = false;
    fg = bg = null;
    _buffer = '';
  }

  void _setupPalettes() {
    ansiColors = [
      [
        AnsiUpColor(rgb: [0, 0, 0], class_name: 'ansi-black'),
        AnsiUpColor(rgb: [187, 0, 0], class_name: 'ansi-red'),
        AnsiUpColor(rgb: [0, 187, 0], class_name: 'ansi-green'),
        AnsiUpColor(rgb: [187, 187, 0], class_name: 'ansi-yellow'),
        AnsiUpColor(rgb: [0, 0, 187], class_name: 'ansi-blue'),
        AnsiUpColor(rgb: [187, 0, 187], class_name: 'ansi-magenta'),
        AnsiUpColor(rgb: [0, 187, 187], class_name: 'ansi-cyan'),
        AnsiUpColor(rgb: [255, 255, 255], class_name: 'ansi-white'),
      ],
      [
        AnsiUpColor(rgb: [85, 85, 85], class_name: 'ansi-bright-black'),
        AnsiUpColor(rgb: [255, 85, 85], class_name: 'ansi-bright-red'),
        AnsiUpColor(rgb: [0, 255, 0], class_name: 'ansi-bright-green'),
        AnsiUpColor(rgb: [255, 255, 85], class_name: 'ansi-bright-yellow'),
        AnsiUpColor(rgb: [85, 85, 255], class_name: 'ansi-bright-blue'),
        AnsiUpColor(rgb: [255, 85, 255], class_name: 'ansi-bright-magenta'),
        AnsiUpColor(rgb: [85, 255, 255], class_name: 'ansi-bright-cyan'),
        AnsiUpColor(rgb: [255, 255, 255], class_name: 'ansi-bright-white'),
      ]
    ];
    palette256 = [];
    for (var palette in ansiColors) {
      palette.forEach(palette256.add);
    }
    var levels = [0, 95, 135, 175, 215, 255];
    for (var r = 0; r < 6; ++r) {
      for (var g = 0; g < 6; ++g) {
        for (var b = 0; b < 6; ++b) {
          palette256.add(AnsiUpColor(
              rgb: [levels[r], levels[g], levels[b]], class_name: 'truecolor'));
        }
      }
    }
    var greyLevel = 8;
    for (var i = 0; i < 24; ++i, greyLevel += 10) {
      palette256.add(AnsiUpColor(
          rgb: [greyLevel, greyLevel, greyLevel], class_name: 'truecolor'));
    }
  }

  TextPacket _getNextPacket() {
    final TextPacket pkt = TextPacket(kind: PacketKind.EOS, text: '', url: '');
    final int len = _buffer.length;
    if (len == 0) return pkt;
    final int pos = _buffer.indexOf('\x1B');
    if (pos == -1) {
      pkt.kind = PacketKind.Text;
      pkt.text = _buffer;
      _buffer = '';
      return pkt;
    }
    if (pos > 0) {
      pkt.kind = PacketKind.Text;
      pkt.text = _buffer.substring(0, pos);
      _buffer = _buffer.substring(pos);
      return pkt;
    }
    if (pos == 0) {
      if (len == 1) {
        pkt.kind = PacketKind.Incomplete;
        return pkt;
      }
      final String nextChar = _buffer[1];
      if ((nextChar != '[') && (nextChar != ']')) {
        pkt.kind = PacketKind.ESC;
        pkt.text = _buffer.substring(0, 1);
        _buffer = _buffer.substring(1);
        return pkt;
      }
      if (nextChar == '[') {
        _csiRegex ??= rgx(
            '\n                        ^                           # beginning of line\n                                                    #\n                                                    # First attempt\n                        (?:                         # legal sequence\n                          \\x1b\\[                      # CSI\n                          ([\\x3c-\\x3f]?)              # private-mode char\n                          ([\\d;]*)                    # any digits or semicolons\n                          ([\\x20-\\x2f]?               # an intermediate modifier\n                          [\\x40-\\x7e])                # the command\n                        )\n                        |                           # alternate (second attempt)\n                        (?:                         # illegal sequence\n                          \\x1b\\[                      # CSI\n                          [\\x20-\\x7e]*                # anything legal\n                          ([\\x00-\\x1f:])              # anything illegal\n                        )\n                    ');
        final RegExpMatch match = _csiRegex.firstMatch(_buffer);
        if (match == null) {
          pkt.kind = PacketKind.Incomplete;
          return pkt;
        }
        if (match.groupCount > 4) {
          pkt.kind = PacketKind.ESC;
          pkt.text = _buffer.substring(0, 1);
          _buffer = _buffer.substring(1);
          return pkt;
        }
        final String match1 = match.groupCount > 1 ? match.group(1) : null;
        final String match3 = match.groupCount > 3 ? match.group(3) : null;
        if ((match1 != '') || (match3 != 'm'))
          pkt.kind = PacketKind.Unknown;
        else
          pkt.kind = PacketKind.SGR;
        pkt.text = match.groupCount > 2 ? match.group(2) : null;
        final int rpos = match.group(0).length;
        _buffer = _buffer.substring(rpos);
        return pkt;
      }
      // TODO: Convert the JS code (below) that handles a ']' character
      // Currently we are only handling '[' characters that are common in ANSI codes
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

  void _appendBuffer(String text) {
    _buffer = _buffer + text;
  }

  void _processAnsi(TextPacket textPacket) {
    final List<String> sgrCmds = textPacket.text.split(';');
    while (sgrCmds.isNotEmpty) {
      final sgrCmdStr = sgrCmds.removeAt(0);
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
        if (sgrCmds.isNotEmpty) {
          final bool isForeground = num == 38;
          final String modeCmd = sgrCmds.removeAt(0);
          if (modeCmd == '5' && sgrCmds.isNotEmpty) {
            final paletteIndex = int.tryParse(sgrCmds.removeAt(0), radix: 10);
            if (paletteIndex >= 0 && paletteIndex <= 255) {
              if (isForeground)
                fg = palette256[paletteIndex];
              else
                bg = palette256[paletteIndex];
            }
          }
          if (modeCmd == '2' && sgrCmds.length > 2) {
            final int r = int.tryParse(sgrCmds.removeAt(0), radix: 10);
            final int g = int.tryParse(sgrCmds.removeAt(0), radix: 10);
            final int b = int.tryParse(sgrCmds.removeAt(0), radix: 10);
            if ((r >= 0 && r <= 255) &&
                (g >= 0 && g <= 255) &&
                (b >= 0 && b <= 255)) {
              var c = AnsiUpColor(rgb: [r, g, b], class_name: 'truecolor');
              if (isForeground)
                fg = c;
              else
                bg = c;
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

  AnsiUpColor fg;
  AnsiUpColor bg;
  bool bold;
  String text;
}

class AnsiUpColor {
  AnsiUpColor({this.rgb, this.class_name});

  List<int> rgb;
  String class_name;
}

mixin PacketKind {
  static const int EOS = 0;
  static const int Text = 1;

  /// An Incomplete ESC sequence.
  static const int Incomplete = 2;

  /// A single ESC char - random.
  static const int ESC = 3;

  /// A valid CSI but not an SGR code.
  static const int Unknown = 4;

  /// Select Graphic Rendition.
  static const int SGR = 5;

  /// Operating System Command.
  static const int OSCURL = 6;
}

class TextPacket {
  TextPacket({this.kind, this.text, this.url});

  /// enum like constant from PacketKind describing the packet.
  int kind;
  String text;
  String url;
}

String _colorToCss(List/*<int>*/ rgb) => 'rgb(${rgb.join(',')})';

RegExp rgx(String regexText) {
  final RegExp wsrgx = RegExp(r"^\s+|\s+\n|\s*#[\s\S]*?\n|\n", multiLine: true);
  final String txt2 = regexText.replaceAll(wsrgx, '');
  return RegExp(txt2);
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
  ansiUp._appendBuffer(text);
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
