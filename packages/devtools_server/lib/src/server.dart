// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:browser_launcher/browser_launcher.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:http_multi_server/http_multi_server.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart' hide Isolate;

import 'client_manager.dart';
import 'external_handlers.dart';
import 'memory_profile.dart';
import 'usage.dart';

const protocolVersion = '1.1.0';
const argHelp = 'help';
const argVmUri = 'vm-uri';
const argEnableNotifications = 'enable-notifications';
const argAllowEmbedding = 'allow-embedding';
const argHeadlessMode = 'headless';
const argDebugMode = 'debug';
const argLaunchBrowser = 'launch-browser';
const argMachine = 'machine';
const argHost = 'host';
const argPort = 'port';
const argProfileMemory = 'profile-memory';
const argTryPorts = 'try-ports';
const argVerbose = 'verbose';
const launchDevToolsService = 'launchDevTools';

const errorLaunchingBrowserCode = 500;

ClientManager clients;

final argParser = ArgParser()
  ..addFlag(
    argHelp,
    negatable: false,
    abbr: 'h',
    help: 'Prints help output.',
  )
  ..addOption(
    argHost,
    defaultsTo: 'localhost',
    help: 'Hostname to serve DevTools on.',
  )
  ..addOption(
    argPort,
    defaultsTo: '9100',
    abbr: 'p',
    help: 'Port to serve DevTools on. '
        'Pass 0 to automatically assign an available port.',
  )
  ..addOption(
    argTryPorts,
    defaultsTo: '1',
    help:
        'The number of ascending ports to try binding to before failing with an error. ',
  )
  ..addOption(
    argVmUri,
    defaultsTo: '',
    help: 'VM Authentication URI',
  )
  ..addOption(
    argProfileMemory,
    defaultsTo: '',
    help: 'Enable memory profiling e.g.,\n'
        '--profile-memory /usr/local/home/my_name/profiles/memory_samples.json\n'
        'writes collected memory statistics to the file specified.',
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
  )
  ..addFlag(
    argEnableNotifications,
    hide: true,
    negatable: false,
    help:
        'Requests notification permissions immediately when a client connects back to the server.',
  )
  ..addFlag(
    argAllowEmbedding,
    hide: true,
    negatable: false,
    help: 'Allow embedding DevTools inside an iframe.',
  )
  ..addFlag(
    argHeadlessMode,
    hide: true,
    negatable: false,
    help:
        'Causes the server to spawn Chrome in headless mode for use in automated testing.',
  )
  ..addFlag(
    argDebugMode,
    hide: true,
    negatable: false,
    help: 'Run a debug build of the DevTools web frontend.',
  )
  ..addFlag(
    argVerbose,
    hide: true,
    negatable: false,
    abbr: 'v',
    help: 'Output more informational messages.',
  );

/// Wraps [serveDevTools] `arguments` parsed, as from the command line.
///
/// For more information on `handler`, see [serveDevTools].
Future<HttpServer> serveDevToolsWithArgs(
  List<String> arguments, {
  shelf.Handler handler,
}) async {
  final args = argParser.parse(arguments);

  final help = args[argHelp];
  final bool machineMode = args[argMachine];
  final bool launchBrowser = args[argLaunchBrowser];
  final bool enableNotifications = args[argEnableNotifications];
  final bool allowEmbedding = args[argAllowEmbedding];
  final port = args[argPort] != null ? int.tryParse(args[argPort]) ?? 0 : 0;
  final bool headlessMode = args[argHeadlessMode];
  final bool debugMode = args[argDebugMode];
  final numPortsToTry =
      args[argTryPorts] != null ? int.tryParse(args[argTryPorts]) ?? 1 : 1;
  final bool verboseMode = args[argVerbose];
  final String hostname = args[argHost];

  // Support collecting profile data.
  final String vmUri = args[argVmUri];
  final String profileAbsoluteFilename = args[argProfileMemory];

  return serveDevTools(
    help: help,
    machineMode: machineMode,
    debugMode: debugMode,
    launchBrowser: launchBrowser,
    enableNotifications: enableNotifications,
    allowEmbedding: allowEmbedding,
    port: port,
    headlessMode: headlessMode,
    numPortsToTry: numPortsToTry,
    handler: handler,
    serviceProtocolUri: vmUri,
    profileFilename: profileAbsoluteFilename,
    verboseMode: verboseMode,
    hostname: hostname,
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
  bool debugMode = false,
  bool launchBrowser = false,
  bool enableNotifications = false,
  bool allowEmbedding = false,
  bool headlessMode = false,
  bool verboseMode = false,
  String hostname = 'localhost',
  int port = 0,
  int numPortsToTry = 1,
  shelf.Handler handler,
  String serviceProtocolUri = '',
  String profileFilename = '',
}) async {
  if (help) {
    print('Dart DevTools version ${await _getVersion()}');
    print('');
    print('usage: devtools <options>');
    print('');
    print(argParser.usage);
    return null;
  }

  // Collect profiling information
  if (serviceProtocolUri.isNotEmpty && profileFilename.isNotEmpty) {
    final observatoryUri = Uri.tryParse(serviceProtocolUri);
    await _hookupMemoryProfiling(observatoryUri, profileFilename, verboseMode);
    return null;
  }

  if (machineMode) {
    assert(enableStdinCommands,
        'machineMode only works with enableStdinCommands.');
  }

  clients = ClientManager(enableNotifications);

  handler ??= await defaultHandler(clients, debugMode: debugMode);

  HttpServer server;
  SocketException ex;
  while (server == null && numPortsToTry > 0) {
    try {
      server = await HttpMultiServer.bind(hostname, port);
    } on SocketException catch (e) {
      ex = e;
      numPortsToTry--;
      port++;
    }
  }

  // Re-throw the last exception if we failed to bind.
  if (server == null && ex != null) {
    throw ex;
  }

  if (allowEmbedding) {
    server.defaultResponseHeaders.remove('x-frame-options', 'SAMEORIGIN');
  }
  // Ensure browsers don't cache older versions of the app.
  server.defaultResponseHeaders
      .add(HttpHeaders.cacheControlHeader, 'max-age=900');
  shelf.serveRequests(server, handler);

  final devToolsUrl = 'http://${server.address.host}:${server.port}';

  if (launchBrowser) {
    await Chrome.start([devToolsUrl.toString()]);
  }

  if (enableStdinCommands) {
    String message = 'Serving DevTools at $devToolsUrl';
    if (!machineMode && debugMode) {
      // Add bold to help find the correct url to open.
      message = '\u001b[1m$message\u001b[0m\n';
    }

    printOutput(
      message,
      {
        'event': 'server.started',
        // TODO(dantup): Remove this `method` field when we're sure VS Code
        // users are all on a newer version that uses `event`. We incorrectly
        // used `method` for the original releases.
        'method': 'server.started',
        'params': {
          'host': server.address.host,
          'port': server.port,
          'pid': pid,
          'protocolVersion': protocolVersion,
        }
      },
      machineMode: machineMode,
    );

    if (machineMode) {
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
            await _handleVmRegister(
              id,
              params,
              machineMode,
              headlessMode,
              devToolsUrl,
            );
            break;
          case 'devTools.launch':
            await _handleDevToolsLaunch(
              id,
              params,
              machineMode,
              headlessMode,
              devToolsUrl,
            );
            break;
          case 'client.list':
            await _handleClientsList(id, params, machineMode);
            break;
          case 'devTools.survey':
            _devToolsUsage ??= DevToolsUsage();
            final String surveyRequest = params['surveyRequest'];
            final String value = params['value'];
            switch (surveyRequest) {
              case 'copyAndCreateDevToolsFile':
                // Backup and delete ~/.devtools file.
                if (backupAndCreateDevToolsStore()) {
                  _devToolsUsage = null;
                  printOutput(
                    'DevTools Survey',
                    {
                      'id': id,
                      'result': {
                        'sucess': true,
                      },
                    },
                    machineMode: machineMode,
                  );
                }
                break;
              case 'restoreDevToolsFile':
                _devToolsUsage = null;
                final content = restoreDevToolsStore();
                if (content != null) {
                  printOutput(
                    'DevTools Survey',
                    {
                      'id': id,
                      'result': {
                        'sucess': true,
                        'content': content,
                      },
                    },
                    machineMode: machineMode,
                  );

                  _devToolsUsage = null;
                }
                break;
              case apiSetActiveSurvey:
                _devToolsUsage.activeSurvey = value;
                printOutput(
                  'DevTools Survey',
                  {
                    'id': id,
                    'result': {
                      'sucess': _devToolsUsage.activeSurvey == value,
                      'activeSurvey': _devToolsUsage.activeSurvey,
                    },
                  },
                  machineMode: machineMode,
                );
                break;
              case apiGetSurveyActionTaken:
                printOutput(
                  'DevTools Survey',
                  {
                    'id': id,
                    'result': {
                      'activeSurvey': _devToolsUsage.activeSurvey,
                      'surveyActionTaken': _devToolsUsage.surveyActionTaken,
                    },
                  },
                  machineMode: machineMode,
                );
                break;
              case apiSetSurveyActionTaken:
                _devToolsUsage.surveyActionTaken = jsonDecode(value);
                printOutput(
                  'DevTools Survey',
                  {
                    'id': id,
                    'result': {
                      'activeSurvey': _devToolsUsage.activeSurvey,
                      'surveyActionTaken': _devToolsUsage.surveyActionTaken,
                    },
                  },
                  machineMode: machineMode,
                );
                break;
              case apiGetSurveyShownCount:
                printOutput(
                  'DevTools Survey',
                  {
                    'id': id,
                    'result': {
                      'activeSurvey': _devToolsUsage.activeSurvey,
                      'surveyShownCount': _devToolsUsage.surveyShownCount,
                    },
                  },
                  machineMode: machineMode,
                );
                break;
              case apiIncrementSurveyShownCount:
                _devToolsUsage.incrementSurveyShownCount();
                printOutput(
                  'DevTools Survey',
                  {
                    'id': id,
                    'result': {
                      'activeSurvey': _devToolsUsage.activeSurvey,
                      'surveyShownCount': _devToolsUsage.surveyShownCount,
                    },
                  },
                  machineMode: machineMode,
                );
                break;
              default:
                printOutput(
                  'Unknown DevTools Survey Request $surveyRequest',
                  {
                    'id': id,
                    'result': {
                      'activeSurvey': _devToolsUsage.activeSurvey,
                      'surveyActionTaken': _devToolsUsage.surveyActionTaken,
                      'surveyShownCount': _devToolsUsage.surveyShownCount,
                    },
                  },
                  machineMode: machineMode,
                );
            }
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
  }

  return server;
}

// Only used for testing DevToolsUsage (used by survey).
DevToolsUsage _devToolsUsage;

File _devToolsBackup;

bool backupAndCreateDevToolsStore() {
  assert(_devToolsBackup == null);
  final devToolsStore = File('${DevToolsUsage.userHomeDir()}/.devtools');
  if (devToolsStore.existsSync()) {
    _devToolsBackup = devToolsStore
        .copySync('${DevToolsUsage.userHomeDir()}/.devtools_backup_test');
    devToolsStore.deleteSync();
  }

  return true;
}

String restoreDevToolsStore() {
  if (_devToolsBackup != null) {
    // Read the current ~/.devtools file
    final devToolsStore = File('${DevToolsUsage.userHomeDir()}/.devtools');
    final content = devToolsStore.readAsStringSync();

    // Delete the temporary ~/.devtools file
    devToolsStore.deleteSync();
    if (_devToolsBackup.existsSync()) {
      // Restore the backup ~/.devtools file we created in backupAndCreateDevToolsStore.
      _devToolsBackup.copySync('${DevToolsUsage.userHomeDir()}/.devtools');
      _devToolsBackup.deleteSync();
      _devToolsBackup = null;
    }
    return content;
  }

  return null;
}

Future<void> _hookupMemoryProfiling(Uri observatoryUri, String profileFile,
    [bool verboseMode = false]) async {
  final VmService service = await _connectToVmService(observatoryUri);
  if (service == null) return;

  MemoryProfile(service, profileFile, verboseMode);

  print('Recording memory profile samples to $profileFile');
}

Future<void> _handleVmRegister(
  dynamic id,
  Map<String, dynamic> params,
  bool machineMode,
  bool headlessMode,
  String devToolsUrl,
) async {
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

  // params['uri'] should contain a vm service uri.
  final uri = Uri.tryParse(params['uri']);

  if (_isValidVmServiceUri(uri)) {
    await registerLaunchDevToolsService(
        uri, id, devToolsUrl, machineMode, headlessMode);
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

Future<void> _handleDevToolsLaunch(
  dynamic id,
  Map<String, dynamic> params,
  bool machineMode,
  bool headlessMode,
  String devToolsUrl,
) async {
  if (!params.containsKey('vmServiceUri')) {
    printOutput(
      'Invalid input: $params does not contain the key \'vmServiceUri\'',
      {
        'id': id,
        'error':
            'Invalid input: $params does not contain the key \'vmServiceUri\'',
      },
      machineMode: machineMode,
    );
  }

  // params['vmServiceUri'] should contain a vm service uri.
  final vmServiceUri = Uri.tryParse(params['vmServiceUri']);

  if (_isValidVmServiceUri(vmServiceUri)) {
    try {
      final result = await launchDevTools(
          params, vmServiceUri, devToolsUrl, headlessMode, machineMode);
      printOutput(
        'DevTools launched',
        {'id': id, 'result': result},
        machineMode: machineMode,
      );
    } catch (e, s) {
      printOutput(
        'Failed to launch browser: $e\n$s',
        {'id': id, 'error': 'Failed to launch browser: $e\n$s'},
        machineMode: machineMode,
      );
    }
  } else {
    printOutput(
      'VM Service URI must be absolute with a http, https, ws or wss scheme',
      {
        'id': id,
        'error':
            'VM Service Uri must be absolute with a http, https, ws or wss scheme',
      },
      machineMode: machineMode,
    );
  }
}

Future<void> _handleClientsList(
    dynamic id, Map<String, dynamic> params, bool machineMode) async {
  final connectedClients = clients.allClients;
  printOutput(
    connectedClients
        .map((c) =>
            '${c.hasConnection.toString().padRight(5, ' ')} ${c.currentPage?.padRight(12, ' ')} ${c.vmServiceUri.toString()}')
        .join('\n'),
    {
      'id': id,
      'result': {
        'clients': connectedClients
            .map((c) => {
                  'hasConnection': c.hasConnection,
                  'currentPage': c.currentPage,
                  'vmServiceUri': c.vmServiceUri?.toString(),
                })
            .toList()
      },
    },
    machineMode: machineMode,
  );
}

Future<bool> _tryReuseExistingDevToolsInstance(
  Uri vmServiceUri,
  String page,
  bool notifyUser,
) async {
  // First try to find a client that's already connected to this VM service,
  // and just send the user a notification for that one.
  final existingClient = clients.findExistingConnectedClient(vmServiceUri);
  if (existingClient != null) {
    try {
      await existingClient.showPage(page);
      if (notifyUser) {
        await existingClient.notify();
      }
      return true;
    } catch (e) {
      print('Failed to reuse existing connected DevTools client');
      print(e);
    }
  }

  final reusableClient = clients.findReusableClient();
  if (reusableClient != null) {
    try {
      await reusableClient.connectToVmService(vmServiceUri, notifyUser);
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
  bool headlessMode,
) async {
  try {
    // Connect to the vm service and register a method to launch DevTools in
    // chrome.
    final VmService service = await _connectToVmService(vmServiceUri);
    if (service == null) return;

    service.registerServiceCallback(launchDevToolsService, (params) async {
      try {
        await launchDevTools(
          params,
          vmServiceUri,
          devToolsUrl,
          headlessMode,
          machineMode,
        );
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

Future<Map<String, dynamic>> launchDevTools(
    Map<String, dynamic> params,
    Uri vmServiceUri,
    String devToolsUrl,
    bool headlessMode,
    bool machineMode) async {
  // First see if we have an existing DevTools client open that we can
  // reuse.
  final canReuse = params != null &&
      params.containsKey('reuseWindows') &&
      params['reuseWindows'] == true;
  final shouldNotify = params != null &&
      params.containsKey('notify') &&
      params['notify'] == true;
  final page = params != null ? params['page'] : null;
  if (canReuse &&
      await _tryReuseExistingDevToolsInstance(
        vmServiceUri,
        page,
        shouldNotify,
      )) {
    _emitLaunchEvent(
        reused: true,
        notified: shouldNotify,
        pid: null,
        machineMode: machineMode);
    return {'reused': true, 'notified': shouldNotify};
  }

  final uriParams = <String, dynamic>{};

  // Copy over queryParams passed by the client
  if (params != null) {
    params['queryParams']?.forEach((key, value) => uriParams[key] = value);
  }

  // Add the URI to the VM service
  uriParams['uri'] = vmServiceUri.toString();

  final devToolsUri = Uri.parse(devToolsUrl);
  final uriToLaunch = _buildUriToLaunch(uriParams, page, devToolsUri);

  // TODO(dantup): When ChromeOS has support for tunneling all ports we
  // can change this to always use the native browser for ChromeOS
  // and may wish to handle this inside `browser_launcher`.
  //   https://crbug.com/848063
  final useNativeBrowser = _isChromeOS &&
      _isAccessibleToChromeOSNativeBrowser(Uri.parse(devToolsUrl)) &&
      _isAccessibleToChromeOSNativeBrowser(vmServiceUri);
  int browserPid;
  if (useNativeBrowser) {
    await Process.start('x-www-browser', [uriToLaunch.toString()]);
  } else {
    final args = headlessMode
        ? [
            '--headless',
            // When running headless, Chrome will quit immediately after loading
            // the page unless we have the debug port open.
            '--remote-debugging-port=9223',
            '--disable-gpu',
            '--no-sandbox',
          ]
        : <String>[];
    final proc = await Chrome.start([uriToLaunch.toString()], args: args);
    browserPid = proc.pid;
  }
  _emitLaunchEvent(
      reused: false,
      notified: false,
      pid: browserPid,
      machineMode: machineMode);
  return {'reused': false, 'notified': false, 'pid': browserPid};
}

String _buildUriToLaunch(
  Map<String, dynamic> uriParams,
  page,
  Uri devToolsUri,
) {
  final queryStringNameValues = [];
  uriParams.forEach((key, value) => queryStringNameValues.add(
      '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}'));

  if (page != null) {
    queryStringNameValues.add('page=${Uri.encodeQueryComponent(page)}');
  }

  return devToolsUri
      .replace(
          path: '${devToolsUri.path.isEmpty ? '/' : devToolsUri.path}',
          fragment: '?${queryStringNameValues.join('&')}')
      .toString();
}

/// Prints a launch event to stdout so consumers of the DevTools server
/// can see when clients are being launched/reused.
void _emitLaunchEvent(
    {@required bool reused,
    @required bool notified,
    @required int pid,
    @required bool machineMode}) {
  printOutput(
    null,
    {
      'event': 'client.launch',
      'params': {'reused': reused, 'notified': notified, 'pid': pid},
    },
    machineMode: machineMode,
  );
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

bool _isValidVmServiceUri(Uri uri) {
  // Lots of things are considered valid URIs (including empty strings and
  // single letters) since they can be relative, so we need to do some extra
  // checks.
  return uri != null &&
      uri.isAbsolute &&
      (uri.isScheme('ws') ||
          uri.isScheme('wss') ||
          uri.isScheme('http') ||
          uri.isScheme('https'));
}

Future<VmService> _connectToVmService(Uri theUri) async {
  // Fix up the various acceptable URI formats into a WebSocket URI to connect.
  final uri = convertToWebSocketUrl(serviceProtocolUrl: theUri);

  try {
    final WebSocket ws = await WebSocket.connect(uri.toString());

    final VmService service = VmService(
      ws.asBroadcastStream(),
      (String message) => ws.add(message),
    );

    return service;
  } catch (_) {
    print('ERROR: Unable to connect to VMService $theUri');
    return null;
  }
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
  final output = machineMode ? jsonEncode(json) : message;
  if (output != null) {
    print(output);
  }
}
