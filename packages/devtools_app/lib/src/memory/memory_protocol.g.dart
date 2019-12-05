// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_protocol.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HeapSample _$HeapSampleFromJson(Map<String, dynamic> json) {
  return HeapSample(
    json['timestamp'] as int,
    json['rss'] as int,
    json['capacity'] as int,
    json['used'] as int,
    json['external'] as int,
    json['gc'] as bool,
  );
}

Map<String, dynamic> _$HeapSampleToJson(HeapSample instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'rss': instance.rss,
      'capacity': instance.capacity,
      'used': instance.used,
      'external': instance.external,
      'gc': instance.isGC,
    };
