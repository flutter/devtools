import 'dart:io';
import 'package:path/path.dart';

import 'package:http_server/http_server.dart' show VirtualDirectory;

final webroot = join(dirname(dirname(Platform.script.toFilePath())), 'build');

Future<void> main() async {
  final virDir = new VirtualDirectory(webroot);

  // Set up a directory handler to serve index.html files.
  virDir.allowDirectoryListing = true;
  virDir.directoryHandler = (dir, request) {
    final indexUri = new Uri.file(dir.path).resolve('index.html');
    virDir.serveFile(new File(indexUri.toFilePath()), request);
  };

  // TODO(dantup): How to decide port?
  final server = await HttpServer.bind('127.0.0.1', 8765);

  virDir.serve(server);
  print('Listening at http://${server.address.host}:${server.port} ...');
}
