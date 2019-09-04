// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:browser_launcher/browser_launcher.dart';
import 'package:http_multi_server/http_multi_server.dart';
import 'package:devtools_server/src/client_manager.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart' hide Isolate;

import 'handlers.dart';

const argHelp = 'help';
const argLaunchBrowser = 'launch-browser';
const argMachine = 'machine';
const argPort = 'port';
const launchDevToolsService = 'launchDevTools';

const errorLaunchingBrowserCode = 500;

final ClientManager clients = ClientManager();

final argParser = ArgParser()
  ..addFlag(
    argHelp,
    negatable: false,
    abbr: 'h',
    help: 'Prints help output.',
  )
  ..addOption(
    argPort,
    defaultsTo: '9100',
    abbr: 'p',
    help: 'Port to serve DevTools on. '
        'Pass 0 to automatically assign an available port.',
  )
  ..addFlag(
    argMachine,
    negatable: false,
    abbr: 'm',
    help: 'Sets output format to JSON for consumption in tools.',
  )
  ..addFlag(
    argLaunchBrowser,
    negatable: false,
    abbr: 'b',
    help: 'Launches DevTools in a browser immediately at start.',
  );

/// Wraps [serveDevTools] `arguments` parsed, as from the command line.
///
/// For more information on `handler`, see [serveDevTools].
Future<HttpServer> serveDevToolsWithArgs(List<String> arguments,
    {shelf.Handler handler}) async {
  final args = argParser.parse(arguments);

  final help = args[argHelp];
  final bool machineMode = args[argMachine];
  final bool launchBrowser = args[argLaunchBrowser];
  final port = args[argPort] != null ? int.tryParse(args[argPort]) ?? 0 : 0;

  return serveDevTools(
    help: help,
    machineMode: machineMode,
    launchBrowser: launchBrowser,
    port: port,
    handler: handler,
  );
}

/// Serves DevTools.
///
/// `handler` is the [shelf.Handler] that the server will use for all requests.
/// If null, [defaultHandler] will be used.
/// Defaults to null.
Future<HttpServer> serveDevTools({
  bool help = false,
  bool enableStdinCommands = true,
  bool machineMode = false,
  bool launchBrowser = false,
  String hostname = 'localhost',
  int port = 0,
  shelf.Handler handler,
}) async {
  if (help) {
    print('Dart DevTools version ${await _getVersion()}');
    print('');
    print('usage: devtools <options>');
    print('');
    print(argParser.usage);
    return null;
  }
  if (machineMode) {
    assert(enableStdinCommands,
        'machineMode only works with enableStdinCommands.');
  }

  handler ??= await defaultHandler(clients);

  final server = await HttpMultiServer.bind(hostname, port);
  shelf.serveRequests(server, handler);

  final devToolsUrl = 'http://${server.address.host}:${server.port}';

  if (launchBrowser) {
    await Chrome.start([devToolsUrl.toString()]);
  }

  if (enableStdinCommands) {
    printOutput(
      'Serving DevTools at $devToolsUrl',
      {
        'event': 'server.started',
        // TODO(dantup): Remove this `method` field when we're sure VS Code users
        // are all on a newer version that uses `event`. We incorrectly used
        // `method` for the original releases.
        'method': 'server.started',
        'params': {'host': server.address.host, 'port': server.port, 'pid': pid}
      },
      machineMode: machineMode,
    );

    final Stream<Map<String, dynamic>> _stdinCommandStream = stdin
        .transform<String>(utf8.decoder)
        .transform<String>(const LineSplitter())
        .where((String line) => line.startsWith('{') && line.endsWith('}'))
        .map<Map<String, dynamic>>((String line) {
      return json.decode(line) as Map<String, dynamic>;
    });

    // Example input:
    // {
    //   "id":0,
    //   "method":"vm.register",
    //   "params":{
    //     "uri":"<vm-service-uri-here>",
    //   }
    // }
    _stdinCommandStream.listen((Map<String, dynamic> json) async {
      // ID can be String, int or null
      final dynamic id = json['id'];
      final Map<String, dynamic> params = json['params'];

      switch (json['method']) {
        case 'vm.register':
          await _handleVmRegister(id, params, machineMode, devToolsUrl);
          break;
        default:
          printOutput(
            'Unknown method ${json['method']}',
            {
              'id': id,
              'error': 'Unknown method ${json['method']}',
            },
            machineMode: machineMode,
          );
      }
    });
  }

  return server;
}

Future<void> _handleVmRegister(dynamic id, Map<String, dynamic> params,
    bool machineMode, String devToolsUrl) async {
  if (!params.containsKey('uri')) {
    printOutput(
      'Invalid input: $params does not contain the key \'uri\'',
      {
        'id': id,
        'error': 'Invalid input: $params does not contain the key \'uri\'',
      },
      machineMode: machineMode,
    );
  }

  // json['uri'] should contain a vm service uri.
  final uri = Uri.tryParse(params['uri']);

  // Lots of things are considered valid URIs (including empty strings
  // and single letters) since they can be relative, so we need to do some
  // extra checks.
  if (uri != null &&
      uri.isAbsolute &&
      (uri.isScheme('ws') ||
          uri.isScheme('wss') ||
          uri.isScheme('http') ||
          uri.isScheme('https'))) {
    await registerLaunchDevToolsService(uri, id, devToolsUrl, machineMode);
  } else {
    printOutput(
      'Uri must be absolute with a http, https, ws or wss scheme',
      {
        'id': id,
        'error': 'Uri must be absolute with a http, https, ws or wss scheme',
      },
      machineMode: machineMode,
    );
  }
}

Future<bool> _tryReuseExistingDevToolsInstance(Uri vmServiceUri) async {
  // First try to find a client that's already connected to this VM service,
  // and just send the user a notification for that one.
  final existingClient = clients.findExistingConnectedClient(vmServiceUri);
  if (existingClient != null) {
    try {
      await existingClient.notify();
      return true;
    } catch (e) {
      print('Failed to reuse existing connected DevTools client');
      print(e);
    }
  }

  final reusableClient = clients.findReusableClient();
  if (reusableClient != null) {
    try {
      await reusableClient.connectToVmService(vmServiceUri);
      // TODO(dantup): Notify won't work properly until we're not reloading
      // the page (otherwise clicking the notifiction spans a new tab, since
      // it doesn't belong to the reloaded page).
      // await reusableClient.notify();
      return true;
    } catch (e) {
      print('Failed to reuse existing DevTools client');
      print(e);
    }
  }
  return false;
}

Future<void> registerLaunchDevToolsService(
  Uri vmServiceUri,
  dynamic id,
  String devToolsUrl,
  bool machineMode,
) async {
  try {
    // Connect to the vm service and register a method to launch DevTools in
    // chrome.
    final VmService service = await _connectToVmService(vmServiceUri);

    service.registerServiceCallback(launchDevToolsService, (params) async {
      try {
        // First see if we have an existing DevTools client open that we can
        // reuse.
        final canReuse = params.containsKey('reuseWindows') &&
            params['reuseWindows'] == true;
        if (canReuse && await _tryReuseExistingDevToolsInstance(vmServiceUri)) {
          return {'result': Success().toJson()};
        }

        final uriParams = <String, dynamic>{};

        // Copy over queryParams passed by the client
        if (params != null) {
          params['queryParams']
              ?.forEach((key, value) => uriParams[key] = value);
        }

        // Add the URI to the VM service
        uriParams['uri'] = vmServiceUri.toString();

        final devToolsUri = Uri.parse(devToolsUrl);
        final uriToLaunch = devToolsUri.replace(
          // If path is empty, we generate 'http://foo:8000?uri=' (missing `/`) and
          // ChromeOS fails to detect that it's a port that's tunneled, and will
          // quietly replace the IP with "penguin.linux.test". This is not valid
          // for us since the server isn't bound to the containers IP (it's bound
          // to the containers loopback IP).
          path: devToolsUri.path.isEmpty ? '/' : devToolsUri.path,
          queryParameters: uriParams,
        );

        // TODO(dantup): When ChromeOS has support for tunneling all ports we
        // can change this to always use the native browser for ChromeOS
        // and may wish to handle this inside `browser_launcher`.
        //   https://crbug.com/848063
        final useNativeBrowser = _isChromeOS &&
            _isAccessibleToChromeOSNativeBrowser(Uri.parse(devToolsUrl)) &&
            _isAccessibleToChromeOSNativeBrowser(vmServiceUri);
        if (useNativeBrowser) {
          await Process.start('x-www-browser', [uriToLaunch.toString()]);
        } else {
          await Chrome.start([uriToLaunch.toString()]);
        }

        return {'result': Success().toJson()};
      } catch (e, s) {
        // Note: It's critical that we return responses in exactly the right format
        // or the VM will unregister the service. The objects must match JSON-RPC
        // however a successful response must also have a "type" field in its result.
        // Otherwise, we can return an error object (instead of result) that includes
        // code + message.
        return {
          'error': {
            'code': errorLaunchingBrowserCode,
            'message': 'Failed to launch browser: $e\n$s',
          },
        };
      }
    });

    // Handle registerService method name change based on protocol version.
    final registerServiceMethodName =
        isVersionLessThan(await service.getVersion(), major: 3, minor: 22)
            ? '_registerService'
            : 'registerService';
    await service.callMethod(registerServiceMethodName,
        args: {'service': launchDevToolsService, 'alias': 'DevTools Server'});

    printOutput(
      'Successfully registered launchDevTools service',
      {
        'id': id,
        'result': {'success': true},
      },
      machineMode: machineMode,
    );
  } catch (e) {
    printOutput(
      'Unable to connect to VM service at $vmServiceUri: $e',
      {
        'id': id,
        'error': 'Unable to connect to VM service at $vmServiceUri: $e',
      },
      machineMode: machineMode,
    );
  }
}

// TODO(dantup): This method was adapted from devtools and should be upstreamed
// in some form into vm_service_lib.
bool isVersionLessThan(
  Version version, {
  @required int major,
  @required int minor,
}) {
  assert(version != null);
  return version.major < major ||
      (version.major == major && version.minor < minor);
}

final bool _isChromeOS = File('/dev/.cros_milestone').existsSync();

bool _isAccessibleToChromeOSNativeBrowser(Uri uri) {
  const tunneledPorts = {8000, 8008, 8080, 8085, 8888, 9005, 3000, 4200, 5000};
  return uri != null && uri.hasPort && tunneledPorts.contains(uri.port);
}

Future<VmService> _connectToVmService(Uri uri) async {
  // Fix up the various acceptable URI formats into a WebSocket URI to connect.
  uri = convertToWebSocketUrl(serviceProtocolUrl: uri);

  final WebSocket ws = await WebSocket.connect(uri.toString());

  final VmService service = VmService(
    ws.asBroadcastStream(),
    (String message) => ws.add(message),
  );

  return service;
}

Future<String> _getVersion() async {
  final Uri resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));
  final String packageDir =
      path.dirname(path.dirname(resourceUri.toFilePath()));
  final File pubspecFile = File(path.join(packageDir, 'pubspec.yaml'));
  final String versionLine =
      pubspecFile.readAsLinesSync().firstWhere((String line) {
    return line.startsWith('version: ');
  }, orElse: () => null);
  return versionLine == null
      ? 'unknown'
      : versionLine.substring('version: '.length).trim();
}

void printOutput(
  String message,
  Object json, {
  @required bool machineMode,
}) {
  print(machineMode ? jsonEncode(json) : message);
}
