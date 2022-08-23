import 'update_version.dart' as update_version;

void main() async {
  final currentVersion = update_version.versionFromPubspecFile();
  if (currentVersion == null) {
    throw 'Version could not be determined from pubspec file';
  }
  final newVersion = incrementDevVersion(currentVersion);
  print('oldversion: $currentVersion newVersion: $newVersion');
  update_version.performTheVersionUpdate(
    currentVersion: currentVersion,
    newVersion: newVersion,
  );
}

String incrementDevVersion(String currentVersion) {
  final alreadyHasDevVersion = RegExp(r'-dev\.\d+').hasMatch(currentVersion);
  if (alreadyHasDevVersion) {
    final devVerMatch = RegExp(
            r'^(?<prefix>\d+\.\d+\.\d+.*-dev\.)(?<devVersion>\d+)(?<suffix>.*)$')
        .firstMatch(currentVersion);

    if (devVerMatch == null) {
      throw 'Invalid version, could not increment dev version';
    } else {
      final prefix = devVerMatch.namedGroup('prefix')!;
      final devVersion = devVerMatch.namedGroup('devVersion')!;
      final suffix = devVerMatch.namedGroup('suffix')!;
      final bumpedDevVersion = int.parse(devVersion, radix: 10) + 1;
      final newVersion = '$prefix$bumpedDevVersion$suffix';

      return newVersion;
    }
  } else {
    return '$currentVersion-dev.0';
  }
}
