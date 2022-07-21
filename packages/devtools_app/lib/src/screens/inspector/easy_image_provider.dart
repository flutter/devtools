import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class EasyImageProvider extends ImageProvider<EasyImageProvider> {
  const EasyImageProvider(this.data, this.key, { this.scale = 1.0 });

  /// The file to decode into an image.
  final Uint8List data;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  final String? key;

  @override
  ImageStreamCompleter load(EasyImageProvider key, decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: this.key,
    );
  }

  Future<ui.Codec> _loadAsync(EasyImageProvider key, DecoderCallback decode) async {
    assert(key == this);

    return decode(data);
  }

  @override
  Future<EasyImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<EasyImageProvider>(this);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is EasyImageProvider
        && other.data == data
        && other.scale == scale;
  }

  @override
  int get hashCode => hashValues(data.hashCode, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'EasyImageProvider')}(${describeIdentity(data)}, scale: $scale)';
}
