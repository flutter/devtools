// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'example/conditional_screen.dart';
import 'extensions/extension_screen.dart';
import 'framework/framework_core.dart';
import 'framework/home_screen.dart';
import 'framework/initializer.dart';
import 'framework/notifications_view.dart';
import 'framework/release_notes/release_notes.dart';
import 'framework/scaffold.dart';
import 'screens/app_size/app_size_controller.dart';
import 'screens/app_size/app_size_screen.dart';
import 'screens/debugger/debugger_controller.dart';
import 'screens/debugger/debugger_screen.dart';
import 'screens/deep_link_validation/deep_links_controller.dart';
import 'screens/deep_link_validation/deep_links_screen.dart';
import 'screens/inspector/inspector_controller.dart';
import 'screens/inspector/inspector_screen.dart';
import 'screens/inspector/inspector_tree_controller.dart';
import 'screens/logging/logging_controller.dart';
import 'screens/logging/logging_screen.dart';
import 'screens/memory/framework/connected/memory_controller.dart';
import 'screens/memory/framework/memory_screen.dart';
import 'screens/memory/framework/static/static_screen_body.dart';
import 'screens/network/network_controller.dart';
import 'screens/network/network_screen.dart';
import 'screens/performance/performance_controller.dart';
import 'screens/performance/performance_screen.dart';
import 'screens/profiler/profiler_screen.dart';
import 'screens/profiler/profiler_screen_controller.dart';
import 'screens/provider/provider_screen.dart';
import 'screens/vm_developer/vm_developer_tools_controller.dart';
import 'screens/vm_developer/vm_developer_tools_screen.dart';
import 'service/service_extension_widgets.dart';
import 'shared/analytics/analytics.dart' as ga;
import 'shared/analytics/analytics_controller.dart';
import 'shared/analytics/metrics.dart';
import 'shared/common_widgets.dart';
import 'shared/console/primitives/simple_items.dart';
import 'shared/feature_flags.dart';
import 'shared/globals.dart';
import 'shared/offline_screen.dart';
import 'shared/primitives/utils.dart';
import 'shared/screen.dart';
import 'shared/ui/hover.dart';
import 'standalone_ui/standalone_screen.dart';

typedef ControllerCreator<T> = T Function(DevToolsAppState state);

const homeScreenId = '/';
const snapshotScreenId = '/snapshot';
const memoryAnalysisScreenId = '/memoryanalysis';

// Assign to true to use a sample implementation of a conditional screen.
// WARNING: Do not check in this file if debugEnableSampleScreen is true.
const debugEnableSampleScreen = false;

// Disabled until VM developer mode functionality is added.
const showVmDeveloperMode = false;

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  const DevToolsApp(
    this.originalScreens,
    this.analyticsController, {
    super.key,
    this.sampleData = const [],
  });

  final List<DevToolsScreen> originalScreens;
  final AnalyticsController analyticsController;
  final List<DevToolsJsonFile> sampleData;

  static DevToolsAppState of(BuildContext context) {
    return context.findAncestorStateOfType<DevToolsAppState>()!;
  }

  @override
  State<DevToolsApp> createState() => DevToolsAppState();
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshals URL query parameters into
/// flutter route parameters.
class DevToolsAppState extends State<DevToolsApp> with AutoDisposeMixin {

  GoRouter? router;
  Uri get _currentUri => router!.routerDelegate.currentConfiguration.uri;
  DevToolsNavigationState? get _currentState => router!.routerDelegate.currentConfiguration.extra as DevToolsNavigationState?;

  static String get currentPage => _currentPage;
  static late String _currentPage;

  List<Screen> get _screens {
    if (FeatureFlags.devToolsExtensions) {
      // TODO(https://github.com/flutter/devtools/issues/6273): stop special
      // casing the package:provider extension.
      final containsProviderExtension = extensionService.visibleExtensions.value
          .where((e) => e.name == 'provider')
          .isNotEmpty;
      final devToolsScreens = containsProviderExtension
          ? _originalScreens
              .where((s) => s.screenId != ScreenMetaData.provider.id)
              .toList()
          : _originalScreens;
      return [...devToolsScreens, ..._extensionScreens];
    }
    return _originalScreens;
  }

  List<Screen> get _originalScreens =>
      widget.originalScreens.map((s) => s.screen).toList();

  Iterable<Screen> get _extensionScreens =>
      extensionService.visibleExtensions.value.map(
        (e) => DevToolsScreen<void>(ExtensionScreen(e)).screen,
      );

  // TODO(dantup): This does not take IDE preference into account, so results
  //  in Dark mode embedded sidebar in VS Code.
  bool get isDarkThemeEnabled => _isDarkThemeEnabled;
  bool _isDarkThemeEnabled = true;

  bool get denseModeEnabled => _denseModeEnabled;
  bool _denseModeEnabled = false;

  final hoverCardController = HoverCardController();

  late ReleaseNotesController releaseNotesController;

  @override
  void initState() {
    super.initState();

    // TODO(https://github.com/flutter/devtools/issues/6018): Once
    // https://github.com/flutter/flutter/issues/129692 is fixed, disable the
    // browser's native context menu on secondary-click, and instead use the
    // menu provided by Flutter:
    // if (kIsWeb) {
    //   unawaited(BrowserContextMenu.disableContextMenu());
    // }

    unawaited(ga.setupDimensions());

    if (FeatureFlags.devToolsExtensions) {
      addAutoDisposeListener(extensionService.availableExtensions, () {
        setState(() {
          _clearGoRouter();
        });
      });
      addAutoDisposeListener(extensionService.visibleExtensions, () {
        setState(() {
          _clearGoRouter();
        });
      });
    }

    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      () {
        setState(() {
          _clearGoRouter();
        });
      },
    );

    _isDarkThemeEnabled = preferences.darkModeTheme.value;
    addAutoDisposeListener(preferences.darkModeTheme, () {
      setState(() {
        _isDarkThemeEnabled = preferences.darkModeTheme.value;
      });
    });

    _denseModeEnabled = preferences.denseModeEnabled.value;
    addAutoDisposeListener(preferences.denseModeEnabled, () {
      setState(() {
        _denseModeEnabled = preferences.denseModeEnabled.value;
      });
    });

    releaseNotesController = ReleaseNotesController();
  }

  GoRouter _initGoRouter() {
    final router = GoRouter(
      routes: _getRoutes(),
      errorBuilder: (_, GoRouterState state) {
        return DevToolsScaffold.withChild(
          key: const Key('not-found'),
          embed: isEmbedded(state.uri.queryParameters),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("'${state.uri.path}' not found."),
                const SizedBox(height: defaultSpacing),
                ElevatedButton(
                  onPressed: () =>
                      GoRouter.of(context).goNamed(homeScreenId),
                  child: const Text('Go to Home screen'),
                ),
              ],
            ),
          ),
        );
      },
    );
    router.routerDelegate.addListener(() {
      _currentPage = router.routerDelegate.currentConfiguration.uri.path;
    });
    return router;
  }

  List<GoRoute> _getRoutes() {
    return <GoRoute>[
      for (final screenPath in pages.keys)
        GoRoute(
          name: screenPath,
          path: screenPath,
          builder: (_, __) {
            return _wrap(
              Builder(builder: pages[screenPath]!),
            );
          },
        ),
    ];
  }

  @override
  void dispose() {
    // preferences is initialized in main() to avoid flash of content with
    // incorrect theme.
    preferences.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DevToolsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clearGoRouter();
  }

  void navigateIfNotCurrent(
    String page, [
      Map<String, String?>? queryParameters,
      DevToolsNavigationState? stateUpdates,
    ]) {
    final pageChanged = page != _currentUri.path;
    final argsChanged = !mapEquals(
      {..._currentUri.queryParameters, ...?queryParameters},
      _currentUri.queryParameters,
    );
    final stateChanged = _currentState?.hasChanges(stateUpdates) ?? stateUpdates != null;
    if (!pageChanged && !argsChanged && !stateChanged) {
      return;
    }

    navigate(page, queryParameters, stateUpdates);
  }

  /// Navigates to a new page, optionally updating arguments and state.
  ///
  /// Existing arguments (for example &uri=) will be preserved unless
  /// overwritten by [argUpdates].
  void navigate(
      String page, [
        Map<String, String?>? argUpdates,
        DevToolsNavigationState? state,
      ]) {
    final uri = router!.routerDelegate.currentConfiguration.uri;
    final queryParameters = {...uri.queryParameters, ...?argUpdates};

    // Ensure we disconnect from any previously connected applications if we do
    // not have a vm service uri as a query parameter, unless we are loading an
    // offline file.
    if (uri.path != snapshotScreenId && queryParameters['uri'] == null) {
      unawaited(serviceConnection.serviceManager.manuallyDisconnect());
    }

    router!.goNamed(
      page,
      queryParameters: queryParameters,
      extra: state,
    );
  }

  void navigateHome({
    bool clearUriParam = false,
    required bool clearScreenParam,
  }) {
    navigate(
      homeScreenId,
      {
        if (clearUriParam) 'uri': null,
        if (clearScreenParam) 'screen': null,
      },
    );
  }

  void updateQueryParametersIfChanged(Map<String, String> queryParameters) {
    final argsChanged = !mapEquals(
      {..._currentUri.queryParameters, ...queryParameters},
      _currentUri.queryParameters,
    );
    if (!argsChanged) {
      return;
    }

    router!.goNamed(
      _currentUri.path,
      queryParameters: queryParameters,
      extra: _currentState,
    );
  }

  void updateStateIfChanged(DevToolsNavigationState stateUpdates) {
    final stateChanged = _currentState?.hasChanges(stateUpdates) ?? true;
    if (!stateChanged) {
      return;
    }

    router!.go(
      _currentUri.toString(),
      extra: stateChanged,
    );
  }

  Widget _wrap(Widget child) {
    if (FrameworkCore.initializationInProgress) {
      return const CenteredCircularProgressIndicator();
    }
    Widget result = child;
    assert(
      () {
        result = _AlternateCheckedModeBanner(builder: (context) => child);
        return true;
      }(),
    );
    return result;
  }

  Widget _buildTabbedPage(
    BuildContext context,
  ) {
    final GoRouterState state = GoRouterState.of(context);
    final queryParams = state.uri.queryParameters;
    final vmServiceUri = queryParams['uri'];
    final embed = isEmbedded(queryParams);
    final hide = {...?queryParams['hide']?.split(',')};

    // TODO(dantup): We should be able simplify this a little, removing params['page']
    // and only supporting /inspector (etc.) instead of also &page=inspector if
    // all IDEs switch over to those URLs.
    String? page = state.path;
    if (state.path?.isEmpty ?? true) {
      page = queryParams['page'];
    }

    final connectedToVmService =
        vmServiceUri != null && vmServiceUri.isNotEmpty;

    Widget scaffoldBuilder() {
      // Force regeneration of visible screens when VM developer mode is
      // enabled and when the list of available extensions change.
      return MultiValueListenableBuilder(
        listenables: [
          preferences.vmDeveloperModeEnabled,
          extensionService.availableExtensions,
          extensionService.visibleExtensions,
        ],
        builder: (_, __, child) {
          final screens = _visibleScreens()
              .where((p) => embed && page != null ? p.screenId == page : true)
              .where((p) => !hide.contains(p.screenId))
              .toList();
          final connectedToFlutterApp =
              serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ??
                  false;
          final connectedToDartWebApp =
              serviceConnection.serviceManager.connectedApp?.isDartWebAppNow ??
                  false;
          return MultiProvider(
            providers: _providedControllers(),
            child: DevToolsScaffold(
              embed: embed,
              page: page,
              screens: screens,
              actions: [
                if (connectedToVmService) ...[
                  // Hide the hot reload button for Dart web apps, where the
                  // hot reload service extension is not avilable and where the
                  // [service.reloadServices] RPC is not implemented.
                  // TODO(https://github.com/flutter/devtools/issues/6441): find
                  // a way to show this for Dart web apps when supported.
                  if (!connectedToDartWebApp)
                    HotReloadButton(
                      callOnVmServiceDirectly: !connectedToFlutterApp,
                    ),
                  // This button will hide itself based on whether the
                  // hot restart service is available for the connected app.
                  const HotRestartButton(),
                ],
                ...DevToolsScaffold.defaultActions(isEmbedded: embed),
              ],
            ),
          );
        },
      );
    }

    return connectedToVmService
        ? Initializer(
            url: vmServiceUri,
            allowConnectionScreenOnDisconnect: !embed,
            builder: (_) => scaffoldBuilder(),
          )
        : scaffoldBuilder();
  }

  /// The pages that the app exposes.
  Map<String, WidgetBuilder> get pages {
    return {
      homeScreenId: _buildTabbedPage,
      for (final screen in _screens) screen.screenId: _buildTabbedPage,
      snapshotScreenId: (_) {
        final queryParameters = GoRouterState.of(context).uri.queryParameters;
        final snapshotArgs = OfflineDataArguments.fromArgs(queryParameters);
        final embed = isEmbedded(queryParameters);
        return DevToolsScaffold.withChild(
          key: UniqueKey(),
          embed: embed,
          child: MultiProvider(
            providers: _providedControllers(offline: true),
            child: OfflineScreenBody(snapshotArgs, _screens),
          ),
        );
      },
      if (FeatureFlags.memoryAnalysis)
        memoryAnalysisScreenId: (_) {
          final embed = isEmbedded(GoRouterState.of(context).uri.queryParameters);
          return DevToolsScaffold.withChild(
            key: const Key('memoryanalysis'),
            embed: embed,
            child: MultiProvider(
              providers: _providedControllers(),
              child: const StaticMemoryBody(),
            ),
          );
        },
      ..._standaloneScreens,
    };
  }

  Map<String, WidgetBuilder> get _standaloneScreens {
    return {
      for (final type in StandaloneScreenType.values)
        '/${type.name}': (_) => type.screen,
    };
  }

  bool isEmbedded(Map<String, String?> args) => args['embed'] == 'true';

  // Map<String, UrlParametersBuilder>? _routes;

  void _clearGoRouter() {
    router?.dispose();
    router = null;
  }

  List<Screen> _visibleScreens() => _screens.where(shouldShowScreen).toList();

  List<Provider> _providedControllers({bool offline = false}) {
    // We use [widget.originalScreens] here instead of [_screens] because
    // extension screens do not provide a controller through this mechanism.
    return widget.originalScreens
        .where(
          (s) => s.providesController && (offline ? s.supportsOffline : true),
        )
        .map((s) => s.controllerProvider(this))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: isDarkThemeEnabled ? ThemeMode.dark : ThemeMode.light,
      theme: themeFor(
        isDarkTheme: false,
        ideTheme: ideTheme,
        theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
      ),
      darkTheme: themeFor(
        isDarkTheme: true,
        ideTheme: ideTheme,
        theme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
      ),
      builder: (context, child) {
        return MultiProvider(
          providers: [
            Provider<AnalyticsController>.value(
              value: widget.analyticsController,
            ),
            Provider<HoverCardController>.value(
              value: hoverCardController,
            ),
            Provider<ReleaseNotesController>.value(
              value: releaseNotesController,
            ),
          ],
          child: NotificationsView(
            child: ReleaseNotesViewer(
              controller: releaseNotesController,
              child: child,
            ),
          ),
        );
      },
      routerConfig: router ??= _initGoRouter(),
      // Disable default scrollbar behavior on web to fix duplicate scrollbars
      // bug, see https://github.com/flutter/flutter/issues/90697:
      scrollBehavior:
          const MaterialScrollBehavior().copyWith(scrollbars: !kIsWeb),
    );
  }
}

/// Encapsulates state associated with a [Router] navigation event.
class DevToolsNavigationState {
  DevToolsNavigationState({
    required this.kind,
    required Map<String, String?> state,
  }) : _state = {
    _kKind: kind,
    ...state,
  };

  factory DevToolsNavigationState.fromJson(Map<String, dynamic> json) =>
      DevToolsNavigationState._(json.cast<String, String?>());

  DevToolsNavigationState._(this._state) : kind = _state[_kKind]!;

  static const _kKind = '_kind';

  final String kind;

  UnmodifiableMapView<String, String?> get state => UnmodifiableMapView(_state);
  final Map<String, String?> _state;

  bool hasChanges(DevToolsNavigationState? other) {
    return !mapEquals(
      {...state, ...?other?.state},
      state,
    );
  }

  /// Creates a new [DevToolsNavigationState] by merging this instance with
  /// [other].
  ///
  /// State contained in [other] will take precedence over state contained in
  /// this instance (e.g., if both instances have state with the same key, the
  /// state in [other] will be used).
  DevToolsNavigationState merge(DevToolsNavigationState other) {
    final newState = <String, String?>{
      ..._state,
      ...other._state,
    };
    return DevToolsNavigationState(kind: kind, state: newState);
  }

  @override
  String toString() => _state.toString();

  Map<String, dynamic> toJson() => _state;
}

/// DevTools screen wrapper that is responsible for creating and providing the
/// screen's controller, if one exists, as well as enabling offline support.
///
/// [C] corresponds to the type of the screen's controller, which is created by
/// [createController] or provided by [controllerProvider].
class DevToolsScreen<C> {
  const DevToolsScreen(
    this.screen, {
    this.createController,
    this.controller,
    this.supportsOffline = false,
  }) : assert(createController == null || controller == null);

  final Screen screen;

  /// Responsible for creating the controller for this screen, if non-null.
  ///
  /// The controller will then be provided via [controllerProvider], and
  /// widgets depending on this controller can access it by calling
  /// `Provider<C>.of(context)`.
  ///
  /// If [createController] and [controller] are both null, [screen] will be
  /// responsible for creating and maintaining its own controller.
  final ControllerCreator<C>? createController;

  /// A provided controller for this screen, if non-null.
  ///
  /// The controller will then be provided via [controllerProvider], and
  /// widgets depending on this controller can access it by calling
  /// `Provider<C>.of(context)`.
  ///
  /// If [createController] and [controller] are both null, [screen] will be
  /// responsible for creating and maintaining its own controller.
  final C? controller;

  /// Returns true if a controller was provided for [screen]. If false,
  /// [screen] is responsible for creating and maintaining its own controller.
  bool get providesController => createController != null || controller != null;

  /// Whether this screen has implemented offline support.
  ///
  /// Defaults to false.
  final bool supportsOffline;

  Provider<C> controllerProvider(DevToolsAppState state) {
    assert((createController != null) != (controller != null));
    final controllerLocal = controller;
    if (controllerLocal != null) {
      return Provider<C>.value(value: controllerLocal);
    }
    return Provider<C>(create: (_) => createController!(state));
  }
}

/// Displays the checked mode banner in the bottom end corner instead of the
/// top end corner.
///
/// This avoids issues with widgets in the appbar being hidden by the banner
/// in a web or desktop app.
class _AlternateCheckedModeBanner extends StatelessWidget {
  const _AlternateCheckedModeBanner({Key? key, required this.builder})
      : super(key: key);
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'DEBUG',
      textDirection: TextDirection.ltr,
      location: BannerLocation.topStart,
      child: Builder(
        builder: builder,
      ),
    );
  }
}

/// Screens to initialize DevTools with.
///
/// If the screen depends on a provided controller, the provider should be
/// provided here.
///
/// Conditional screens can be added to this list, and they will automatically
/// be shown or hidden based on the [Screen.conditionalLibrary] provided.
List<DevToolsScreen> defaultScreens({
  List<DevToolsJsonFile> sampleData = const [],
}) {
  return devtoolsScreens ??= <DevToolsScreen>[
    DevToolsScreen<void>(HomeScreen(sampleData: sampleData)),
    DevToolsScreen<InspectorController>(
      InspectorScreen(),
      createController: (_) => InspectorController(
        inspectorTree: InspectorTreeController(
          gaId: InspectorScreenMetrics.summaryTreeGaId,
        ),
        detailsTree: InspectorTreeController(
          gaId: InspectorScreenMetrics.detailsTreeGaId,
        ),
        treeType: FlutterTreeType.widget,
      ),
    ),
    DevToolsScreen<PerformanceController>(
      PerformanceScreen(),
      createController: (_) => PerformanceController(),
      supportsOffline: true,
    ),
    DevToolsScreen<ProfilerScreenController>(
      ProfilerScreen(),
      createController: (_) => ProfilerScreenController(),
      supportsOffline: true,
    ),
    DevToolsScreen<MemoryController>(
      MemoryScreen(),
      createController: (_) => MemoryController(),
    ),
    DevToolsScreen<DebuggerController>(
      DebuggerScreen(),
      createController: (DevToolsAppState state) => DebuggerController(state),
    ),
    DevToolsScreen<NetworkController>(
      NetworkScreen(),
      createController: (_) => NetworkController(),
    ),
    DevToolsScreen<LoggingController>(
      LoggingScreen(),
      createController: (_) => LoggingController(),
    ),
    DevToolsScreen<void>(ProviderScreen()),
    DevToolsScreen<AppSizeController>(
      AppSizeScreen(),
      createController: (_) => AppSizeController(),
    ),
    if (FeatureFlags.deepLinkValidation)
      DevToolsScreen<DeepLinksController>(
        DeepLinksScreen(),
        createController: (_) => DeepLinksController(),
      ),
    DevToolsScreen<VMDeveloperToolsController>(
      VMDeveloperToolsScreen(),
      createController: (_) => VMDeveloperToolsController(),
    ),
    // Show the sample DevTools screen.
    if (debugEnableSampleScreen && (kDebugMode || kProfileMode))
      DevToolsScreen<ExampleController>(
        const ExampleConditionalScreen(),
        createController: (_) => ExampleController(),
        supportsOffline: true,
      ),
  ];
}

@visibleForTesting
List<DevToolsScreen>? devtoolsScreens;
