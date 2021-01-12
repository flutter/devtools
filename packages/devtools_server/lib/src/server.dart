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
import 'file_system.dart';
import 'memory_profile.dart';
import 'usage.dart';

const protocolVersion = '1.1.0';
const argHelp = 'help';
const argVmUri = 'vm-uri';
const argEnableNotifications = 'enable-notifications';
const argAllowEmbedding = 'allow-embedding';
const argAppSizeBase = 'appSizeBase';
const argAppSizeTest = 'appSizeTest';
const argHeadlessMode = 'headless';
const argDebugMode = 'debug';
const argLaunchBrowser = 'launch-browser';
const argMachine = 'machine';
const argHost = 'host';
const argPort = 'port';
const argProfileMemory = 'record-memory-profile';
const argProfileMemoryOld = 'profile-memory';
const argTryPorts = 'try-ports';
const argVerbose = 'verbose';
const launchDevToolsService = 'launchDevTools';

const defaultTryPorts = 10;

const errorLaunchingBrowserCode = 500;

ClientManager clients;

/// Wraps [serveDevTools] `arguments` parsed, as from the command line.
///
/// For more information on `handler`, see [serveDevTools].
// Note: this method is used in google3 as well as by DevTools' main method.
Future<void> serveDevToolsWithArgs(
  List<String> arguments, {
  shelf.Handler handler,
}) async {
  ArgResults args;
  final verbose = arguments.contains('-v') || arguments.contains('--verbose');
  try {
    args = _createArgsParser(verbose).parse(arguments);
  } on FormatException catch (e) {
    print(e.message);
    print('');
    _printUsage(verbose);
    return;
  }

  return await _serveDevToolsWithArgs(args, verbose, handler: handler);
}

Future<void> _serveDevToolsWithArgs(
  ArgResults args,
  bool verbose, {
  shelf.Handler handler,
}) async {
  final help = args[argHelp];
  final bool machineMode = args[argMachine];
  // launchBrowser defaults based on machine-mode if not explicitly supplied.
  final bool launchBrowser =
      args.wasParsed(argLaunchBrowser) ? args[argLaunchBrowser] : !machineMode;
  final bool enableNotifications = args[argEnableNotifications];
  final bool allowEmbedding = args[argAllowEmbedding];
  final port = args[argPort] != null ? int.tryParse(args[argPort]) ?? 0 : 0;
  final bool headlessMode = args[argHeadlessMode];
  final bool debugMode = args[argDebugMode];
  final numPortsToTry = args[argTryPorts] != null
      ? int.tryParse(args[argTryPorts]) ?? defaultTryPorts
      : defaultTryPorts;
  final bool verboseMode = args[argVerbose];
  final String hostname = args[argHost];
  final String appSizeBase = args[argAppSizeBase];
  final String appSizeTest = args[argAppSizeTest];

  if (help) {
    print('Dart DevTools version ${await _getVersion()}');
    print('');
    _printUsage(verbose);
    return;
  }

  // Prefer getting the VM URI from the rest args; fall back on the 'vm-url'
  // option otherwise.
  String serviceProtocolUri;
  if (args.rest.isNotEmpty) {
    serviceProtocolUri = args.rest.first;
  } else if (args.wasParsed(argVmUri)) {
    serviceProtocolUri = args[argVmUri];
  }

  // Support collecting profile data.
  String profileFilename;
  if (args.wasParsed(argProfileMemory)) {
    profileFilename = args[argProfileMemory];
  } else if (args.wasParsed(argProfileMemoryOld)) {
    profileFilename = args[argProfileMemoryOld];
  }
  if (profileFilename != null && !path.isAbsolute(profileFilename)) {
    profileFilename = path.absolute(profileFilename);
  }

  return serveDevTools(
    machineMode: machineMode,
    debugMode: debugMode,
    launchBrowser: launchBrowser,
    enableNotifications: enableNotifications,
    allowEmbedding: allowEmbedding,
    port: port,
    headlessMode: headlessMode,
    numPortsToTry: numPortsToTry,
    handler: handler,
    serviceProtocolUri: serviceProtocolUri,
    profileFilename: profileFilename,
    verboseMode: verboseMode,
    hostname: hostname,
    appSizeBase: appSizeBase,
    appSizeTest: appSizeTest,
  );
}

/// Serves DevTools.
///
/// `handler` is the [shelf.Handler] that the server will use for all requests.
/// If null, [defaultHandler] will be used. Defaults to null.
// Note: this method is used by the Flutter CLI and by package:dwds.
Future<HttpServer> serveDevTools({
  bool enableStdinCommands = true,
  bool machineMode = false,
  bool debugMode = false,
  bool launchBrowser = false,
  bool enableNotifications = false,
  bool allowEmbedding = false,
  bool headlessMode = false,
  bool verboseMode = false,
  String hostname,
  int port = 0,
  int numPortsToTry = defaultTryPorts,
  shelf.Handler handler,
  String serviceProtocolUri,
  String profileFilename,
  String appSizeBase,
  String appSizeTest,
}) async {
  hostname ??= 'localhost';

  // Collect profiling information.
  if (profileFilename != null && serviceProtocolUri != null) {
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
  while (server == null && numPortsToTry >= 0) {
    // If we have tried [numPortsToTry] ports and still have not been able to
    // connect, try port 0 to find a random available port.
    if (numPortsToTry == 0) port = 0;

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
    if (serviceProtocolUri != null) {
      serviceProtocolUri =
          _normalizeVmServiceUri(serviceProtocolUri).toString();
    }

    final queryParameters = {
      if (serviceProtocolUri != null) 'uri': serviceProtocolUri,
      if (appSizeBase != null) 'appSizeBase': appSizeBase,
      if (appSizeTest != null) 'appSizeTest': appSizeTest,
    };
    String url = Uri.parse(devToolsUrl)
        .replace(queryParameters: queryParameters)
        .toString();

    // If app size parameters are present, open to the standalone `appsize`
    // page, regardless if there is a vm service uri specified. We only check
    // for the presence of [appSizeBase] here because [appSizeTest] may or may
    // not be specified (it should only be present for diffs). If [appSizeTest]
    // is present without [appSizeBase], we will ignore the parameter.
    if (appSizeBase != null) {
      final startQueryParamIndex = url.indexOf('?');
      if (startQueryParamIndex != -1) {
        url = '${url.substring(0, startQueryParamIndex)}'
            '/#/appsize'
            '${url.substring(startQueryParamIndex)}';
      }
    }

    try {
      await Chrome.start([url]);
    } catch (e) {
      print('Unable to launch Chrome: $e\n');
    }
  }

  if (enableStdinCommands) {
    String message = 'Serving DevTools at $devToolsUrl.\n'
        '\n'
        'Hit ctrl-c to terminate the server.';
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

    // TODO: Refactor machine mode out into a separate class.
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

ArgParser _createArgsParser(bool verbose) {
  final parser = ArgParser();

  parser
    ..addFlag(
      argHelp,
      negatable: false,
      abbr: 'h',
      help: 'Prints help output.',
    )
    ..addFlag(
      argVerbose,
      negatable: false,
      abbr: 'v',
      help: 'Output more informational messages.',
    )
    ..addOption(
      argHost,
      //defaultsTo: 'localhost',
      valueHelp: 'host',
      help: 'Hostname to serve DevTools on (defaults to localhost).',
    )
    ..addOption(
      argPort,
      defaultsTo: '9100',
      valueHelp: 'port',
      help: 'Port to serve DevTools on; specify 0 to automatically use any '
          'available port.',
    )
    ..addFlag(
      argLaunchBrowser,
      help:
          'Launches DevTools in a browser immediately at start.\n(defaults to on unless in --machine mode)',
    )
// TODO: Remove this - prefer that clients use the rest arg.
    ..addOption(
      argVmUri,
      defaultsTo: '',
      help: 'VM Service protocol URI.',
      hide: true,
    )
    ..addFlag(
      argMachine,
      negatable: false,
      help: 'Sets output format to JSON for consumption in tools.',
    )
    ..addOption(
      argProfileMemory,
      valueHelp: 'file',
      defaultsTo: 'memory_samples.json',
      help:
          'Start devtools headlessly and write memory profiling samples to the '
          'indicated file.',
    )
// TODO: Remove this after a release or two.
    ..addOption(
      argProfileMemoryOld,
      defaultsTo: 'memory_samples.json',
      hide: true,
    )
    ..addOption(
      argAppSizeBase,
      valueHelp: 'appSizeBase',
      help: 'Path to the base app size file used for app size debugging.',
      hide: true,
    )
    ..addOption(
      argAppSizeTest,
      valueHelp: 'appSizeTest',
      help: 'Path to the test app size file used for app size debugging. This '
          'file should only be specified if a base app size file (appSizeBase) '
          'is also specified.',
      hide: true,
    );

  // Args to show for verbose mode.
  parser
    ..addOption(
      argTryPorts,
      defaultsTo: defaultTryPorts.toString(),
      valueHelp: 'count',
      help: 'The number of ascending ports to try binding to before failing '
          'with an error. ',
      hide: !verbose,
    )
    ..addFlag(
      argEnableNotifications,
      negatable: false,
      help: 'Requests notification permissions immediately when a client '
          'connects back to the server.',
      hide: !verbose,
    )
    ..addFlag(
      argAllowEmbedding,
      negatable: false,
      help: 'Allow embedding DevTools inside an iframe.',
      hide: !verbose,
    )
    ..addFlag(
      argHeadlessMode,
      negatable: false,
      help: 'Causes the server to spawn Chrome in headless mode for use in '
          'automated testing.',
      hide: !verbose,
    );

  // Hidden args.
  parser
    ..addFlag(
      argDebugMode,
      negatable: false,
      help: 'Run a debug build of the DevTools web frontend.',
      hide: true,
    );

  return parser;
}

void _printUsage(bool verbose) {
  print('usage: devtools <options> [service protocol uri]');
  print('');
  print('Open a DevTools instance in a browser and optionally connect to an '
      'existing application.');
  print('');
  print(_createArgsParser(verbose).usage);
}

// Only used for testing DevToolsUsage (used by survey).
DevToolsUsage _devToolsUsage;

File _devToolsBackup;

bool backupAndCreateDevToolsStore() {
  assert(_devToolsBackup == null);
  final devToolsStore = File(_devToolsStoreLocation());
  if (devToolsStore.existsSync()) {
    _devToolsBackup = devToolsStore
        .copySync('${LocalFileSystem.devToolsDir()}/.devtools_backup_test');
    devToolsStore.deleteSync();
  }

  return true;
}

String restoreDevToolsStore() {
  if (_devToolsBackup != null) {
    // Read the current ~/.devtools file
    LocalFileSystem.maybeMoveLegacyDevToolsStore();
    final devToolsStore = File(_devToolsStoreLocation());
    final content = devToolsStore.readAsStringSync();

    // Delete the temporary ~/.devtools file
    devToolsStore.deleteSync();
    if (_devToolsBackup.existsSync()) {
      // Restore the backup ~/.devtools file we created in
      // backupAndCreateDevToolsStore.
      _devToolsBackup.copySync(_devToolsStoreLocation());
      _devToolsBackup.deleteSync();
      _devToolsBackup = null;
    }
    return content;
  }

  return null;
}

String _devToolsStoreLocation() {
  return path.join(LocalFileSystem.devToolsDir(), DevToolsUsage.storeName);
}

Future<void> _hookupMemoryProfiling(
  Uri observatoryUri,
  String profileFile, [
  bool verboseMode = false,
]) async {
  final VmService service = await _connectToVmService(observatoryUri);
  if (service == null) {
    return;
  }

  final memoryProfiler = MemoryProfile(service, profileFile, verboseMode);
  memoryProfiler.startPolling();

  print('Writing memory profile samples to $profileFile...');
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
    connectedClients.map((c) {
      return '${c.hasConnection.toString().padRight(5, ' ')} '
          '${c.currentPage?.padRight(12, ' ')} ${c.vmServiceUri.toString()}';
    }).join('\n'),
    {
      'id': id,
      'result': {
        'clients': connectedClients
            .map((c) => {
                  'hasConnection': c.hasConnection,
                  'currentPage': c.currentPage,
                  'embedded': c.embedded,
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
  final existingClient =
      clients.findExistingConnectedReusableClient(vmServiceUri);
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

  // TODO(dantup): When ChromeOS has support for tunneling all ports we can
  // change this to always use the native browser for ChromeOS and may wish to
  // handle this inside `browser_launcher`; https://crbug.com/848063.
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

// Note: please keep this copy of normalizeVmServiceUri() in sync with the one
// in devtools_app.
Uri _normalizeVmServiceUri(String value) {
  value = value.trim();

  // Cleanup encoded urls likely copied from the uri of an existing running
  // DevTools app.
  if (value.contains('%3A%2F%2F')) {
    value = Uri.decodeFull(value);
  }
  final uri = Uri.parse(value.trim()).removeFragment();
  if (!uri.isAbsolute) {
    return null;
  }
  if (uri.path.endsWith('/')) return uri;
  return uri.replace(path: uri.path);
}
