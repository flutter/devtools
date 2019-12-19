// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_model.dart';

// **************************************************************************
// CerealGenerator
// **************************************************************************

extension $TraceEvent on TraceEvent {
  Map<String, dynamic> toJson() {
    final __result = <String, dynamic>{};
    if (name != null) __result['name'] = name;
    if (cat != null) __result['cat'] = cat;
    if (ph != null) __result['ph'] = ph;
    if (pid != null) __result['pid'] = pid;
    if (tid != null) __result['tid'] = tid;
    if (id != null) __result['id'] = id;
    if (scope != null) __result['scope'] = scope;
    if (dur != null) __result['dur'] = dur;
    if (ts != null) __result['ts'] = ts;
    if (args != null) __result['args'] = args;
    return __result;
  }
}

extension $TraceEvent$Reviver on JsonCodec {
  TraceEvent decodeTraceEvent(String input) => toTraceEvent(decode(input));
  TraceEvent toTraceEvent(dynamic decoded) {
    final map = decoded;
    final String name = map["name"] == null ? null : map['name'];
    final String cat = map["cat"] == null ? null : map['cat'];
    final String ph = map["ph"] == null ? null : map['ph'];
    final int pid = map["pid"] == null
        ? null
        : (map['pid'] is int || map['pid'] == null)
            ? map['pid']
            : int.parse(map['pid']);
    final int tid = map["tid"] == null
        ? null
        : (map['tid'] is int || map['tid'] == null)
            ? map['tid']
            : int.parse(map['tid']);
    final dynamic id = map["id"] == null ? null : null;
    final String scope = map["scope"] == null ? null : map['scope'];
    final int dur = map["dur"] == null
        ? null
        : (map['dur'] is int || map['dur'] == null)
            ? map['dur']
            : int.parse(map['dur']);
    final int ts = map["ts"] == null
        ? null
        : (map['ts'] is int || map['ts'] == null)
            ? map['ts']
            : int.parse(map['ts']);
    final Map<String, dynamic> args = map["args"] == null ? null : map['args'];
    return TraceEvent(
      name: name,
      cat: cat,
      ph: ph,
      pid: pid,
      tid: tid,
      id: id,
      scope: scope,
      dur: dur,
      ts: ts,
      args: args,
    );
  }
}
