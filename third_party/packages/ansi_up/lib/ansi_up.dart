// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: prefer_const_declarations

/// ansi_up is an library that parses text containing ANSI color escape
/// codes.
@JS()
library ansi_up;

import 'package:js/js.dart';

@JS()
class AnsiUp {
  external AnsiUp();

  external TextPacket get_next_packet();

  external void append_buffer(String text);

  external void process_ansi(TextPacket textPacket);
  external TextWithAttr with_state(TextPacket packet);
}

@JS()
class TextWithAttr {
  external AU_Color get fg;
  external AU_Color get bg;
  external bool get bold;
  external String get text;
}

@JS()
@anonymous
class AU_Color {
  external List<int> get rgb;
  external String get class_name;
}

class PacketKind {
  static final int EOS = 0;
  static final int Text = 1;

  /// An Incomplete ESC sequence.
  static final int Incomplete = 2;

  /// A single ESC char - random.
  static final int ESC = 3;

  /// A valid CSI but not an SGR code.
  static final int Unknown = 4;

  /// Select Graphic Rendition.
  static final int SGR = 5;

  /// Operating System Command.
  static final int OSCURL = 6;
}

@JS()
@anonymous
class TextPacket {
  /// enum like constant from PacketKind describing the packet.
  external int get kind;
  external String get text;
  external String get url;
}

String _colorToCss(List/*<int>*/ rgb) => 'rgb(${rgb.join(',')})';

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
  ansiUp.append_buffer(text);

  while (true) {
    final packet = ansiUp.get_next_packet();

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
      yield StyledText.from(ansiUp.with_state(packet));
    } else if (packet.kind == PacketKind.SGR) {
      ansiUp.process_ansi(packet);
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
