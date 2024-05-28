// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'screens/logging/logging_screen_v2/logging_controller_v2.dart';
import 'screens/logging/logging_screen_v2/logging_screen_v2.dart';
import 'screens/memory/framework/memory_controller.dart';
import 'screens/memory/framework/memory_screen.dart';
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
import 'shared/offline_data.dart';
import 'shared/offline_screen.dart';
import 'shared/primitives/utils.dart';
import 'shared/query_parameters.dart';
import 'shared/routing.dart';
import 'shared/screen.dart';
import 'shared/ui/hover.dart';
import 'shared/utils.dart';
import 'standalone_ui/standalone_screen.dart';

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
  });

  final List<DevToolsScreen> originalScreens;
  final AnalyticsController analyticsController;

  @override
  State<DevToolsApp> createState() => DevToolsAppState();
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshals URL query parameters into
/// flutter route parameters.
class DevToolsAppState extends State<DevToolsApp> with AutoDisposeMixin {
  List<Screen> get _screens {
    if (FeatureFlags.devToolsExtensions) {
      // TODO(https://github.com/flutter/devtools/issues/6273): stop special
      // casing the package:provider extension.
      final containsProviderExtension = extensionService
          .currentExtensions.value.visibleExtensions
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
      extensionService.visibleExtensions.map(
        (e) => DevToolsScreen<void>(ExtensionScreen(e)).screen,
      );

  bool get isDarkThemeEnabled {
    // We use user preference when not embedded. When embedded, we always use
    // the IDE one (since the user can't access the preference, and the
    // preference may have been set in an external window and differ from the
    // IDE theme).
    return isEmbedded() ? ideTheme.isDarkMode : _isDarkThemeEnabledPreference;
  }

  bool _isDarkThemeEnabledPreference = true;

  final hoverCardController = HoverCardController();

  late ReleaseNotesController releaseNotesController;

  late final routerDelegate = DevToolsRouterDelegate(_getPage);

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

    void clearRoutesAndSetState() {
      setState(() {
        _clearCachedRoutes();
      });
    }

    if (FeatureFlags.devToolsExtensions) {
      addAutoDisposeListener(
        extensionService.currentExtensions,
        clearRoutesAndSetState,
      );
    }

    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      clearRoutesAndSetState,
    );

    _isDarkThemeEnabledPreference = preferences.darkModeTheme.value;
    addAutoDisposeListener(preferences.darkModeTheme, () {
      setState(() {
        _isDarkThemeEnabledPreference = preferences.darkModeTheme.value;
      });
    });

    releaseNotesController = ReleaseNotesController();
  }

  @override
  void dispose() {
    FrameworkCore.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DevToolsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clearCachedRoutes();
  }

  /// Gets the page for a given page/path and args.
  Page _getPage(
    BuildContext context,
    String? page,
    DevToolsQueryParams params,
    DevToolsNavigationState? state,
  ) {
    // `page` will initially be null while the router is set up, then we will
    // be called again with an empty string for the root.
    if (FrameworkCore.initializationInProgress || page == null) {
      return const MaterialPage(child: CenteredCircularProgressIndicator());
    }

    // Provide the appropriate page route.
    if (pages.containsKey(page)) {
      Widget widget = pages[page]!(
        context,
        page,
        params,
        state,
      );
      assert(
        () {
          widget = _AlternateCheckedModeBanner(
            builder: (context) => pages[page]!(
              context,
              page,
              params,
              state,
            ),
          );
          return true;
        }(),
      );
      return MaterialPage(child: widget);
    }

    // Return a page not found.
    return MaterialPage(
      child: DevToolsScaffold.withChild(
        key: const Key('not-found'),
        embedMode: params.embedMode,
        child: PageNotFound(
          page: page,
          routerDelegate: routerDelegate,
        ),
      ),
    );
  }

  Widget _buildTabbedPage(
    BuildContext _,
    String? page,
    DevToolsQueryParams queryParams,
    DevToolsNavigationState? __,
  ) {
    final vmServiceUri = queryParams.vmServiceUri;
    final embedMode = queryParams.embedMode;

    // TODO(dantup): We should be able simplify this a little, removing params['page']
    // and only supporting /inspector (etc.) instead of also &page=inspector if
    // all IDEs switch over to those URLs.
    if (page?.isEmpty ?? true) {
      page = queryParams.legacyPage;
    }

    final connectedToVmService =
        vmServiceUri != null && vmServiceUri.isNotEmpty;

    Widget scaffoldBuilder() {
      // Force regeneration of visible screens when VM developer mode is
      // enabled and when the list of available extensions change.
      return MultiValueListenableBuilder(
        listenables: [
          preferences.vmDeveloperModeEnabled,
          extensionService.currentExtensions,
        ],
        builder: (_, __, child) {
          final screens = _visibleScreens()
              .where(
                (s) => maybeIncludeOnlyEmbeddedScreen(
                  s,
                  page: page,
                  embedMode: embedMode,
                ),
              )
              .toList();

          removeHiddenScreens(screens, queryParams);

          DevToolsScaffold scaffold;
          if (screens.isEmpty) {
            // TODO(https://github.com/dart-lang/pub-dev/issues/7216): add an
            // extensions store or a link to a pub.dev query for packages with
            // extensions.
            scaffold = DevToolsScaffold.withChild(
              embedMode: embedMode,
              child: CenteredMessage(
                'No DevTools '
                '${queryParams.hideAllExceptExtensions ? 'extensions' : 'screens'} '
                'available for your project.',
              ),
            );
          } else {
            final connectedToFlutterApp = serviceConnection
                    .serviceManager.connectedApp?.isFlutterAppNow ??
                false;
            final connectedToDartWebApp = serviceConnection
                    .serviceManager.connectedApp?.isDartWebAppNow ??
                false;
            scaffold = DevToolsScaffold(
              embedMode: embedMode,
              page: page,
              screens: screens,
              actions: isEmbedded()
                  ? []
                  : [
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
                      ...DevToolsScaffold.defaultActions(),
                    ],
            );
          }
          return MultiProvider(
            providers: _providedControllers(),
            child: scaffold,
          );
        },
      );
    }

    return connectedToVmService
        ? Initializer(
            url: vmServiceUri,
            allowConnectionScreenOnDisconnect: !embedMode.embedded,
            builder: (_) => scaffoldBuilder(),
          )
        : scaffoldBuilder();
  }

  /// The pages that the app exposes.
  Map<String, UrlParametersBuilder> get pages {
    return _routes ??= {
      homeScreenId: _buildTabbedPage,
      for (final screen in _screens) screen.screenId: _buildTabbedPage,
      snapshotScreenId: (_, __, params, ___) {
        return DevToolsScaffold.withChild(
          key: UniqueKey(),
          embedMode: params.embedMode,
          child: MultiProvider(
            providers: _providedControllers(offline: true),
            child: OfflineScreenBody(params.offlineScreenId, _screens),
          ),
        );
      },
      ..._standaloneScreens,
    };
  }

  Map<String, UrlParametersBuilder> get _standaloneScreens {
    // TODO(dantup): Standalone screens do not use DevToolsScaffold which means
    //  they do not currently send an initial "currentPage" event to inform
    //  the server which page they are rendering.
    return {
      for (final type in StandaloneScreenType.values)
        type.name: (_, __, args, ___) => type.screen,
    };
  }

  Map<String, UrlParametersBuilder>? _routes;

  void _clearCachedRoutes() {
    _routes = null;
    routerDelegate.refreshPages();
  }

  List<Screen> _visibleScreens() => _screens.where(shouldShowScreen).toList();

  List<Provider> _providedControllers({bool offline = false}) {
    // We use [widget.originalScreens] here instead of [_screens] because
    // extension screens do not provide a controller through this mechanism.
    return widget.originalScreens
        .where(
          (s) =>
              s.providesController &&
              (offline ? s.screen.worksWithOfflineData : true),
        )
        .map((s) => s.controllerProvider(routerDelegate))
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
      routerDelegate: routerDelegate,
      routeInformationParser: DevToolsRouteInformationParser(),
      // Disable default scrollbar behavior on web to fix duplicate scrollbars
      // bug, see https://github.com/flutter/flutter/issues/90697:
      scrollBehavior:
          const MaterialScrollBehavior().copyWith(scrollbars: !kIsWeb),
    );
  }

  /// Helper function that will be used in a 'List.where' call to generate a
  /// list of [Screen]s to pass to a [DevToolsScaffold].
  ///
  /// When [embedMode] is [EmbedMode.embedOne], this method will return true
  /// only when [screen] matches the specified [page]. Otherwise, this method
  /// will return true for any [screen].
  @visibleForTesting
  static bool maybeIncludeOnlyEmbeddedScreen(
    Screen screen, {
    required String? page,
    required EmbedMode embedMode,
  }) {
    if (embedMode == EmbedMode.embedOne && page != null) {
      return screen.screenId == page;
    }
    return true;
  }

  /// Helper function that removes any hidden screens from [screens] based on
  /// the value of the 'hide' query parameter in [params].
  @visibleForTesting
  static void removeHiddenScreens(
    List<Screen> screens,
    DevToolsQueryParams params,
  ) {
    screens.removeWhere((s) => params.hiddenScreens.contains(s.screenId));

    // When 'hide=extensions' is in the query parameters, this remove all
    // extension screens.
    if (params.hideExtensions) {
      screens.removeWhere((s) => s is ExtensionScreen);
    }

    // When 'hide=all-except-extensions' is in the query parameters, remove all
    // non-extension screens.
    if (params.hideAllExceptExtensions) {
      screens.removeWhere((s) => s is! ExtensionScreen);
    }
  }
}

/// DevTools screen wrapper that is responsible for creating and providing the
/// screen's controller, if one exists, as well as enabling offline support.
///
/// [C] corresponds to the type of the screen's controller, which is created by
/// [createController] or provided by [controllerProvider].
class DevToolsScreen<C extends Object?> {
  const DevToolsScreen(this.screen, {this.createController});

  final Screen screen;

  /// Responsible for creating the controller for this screen, if non-null.
  ///
  /// The controller will then be provided via [controllerProvider], and
  /// widgets depending on this controller can access it by calling
  /// `Provider<C>.of(context)`.
  ///
  /// If [createController] and [controller] are both null, [screen] will be
  /// responsible for creating and maintaining its own controller.
  ///
  /// In the controller initialization, if logic requires a connected [VmService]
  /// object (`serviceConnection.serviceManager.service`), then the controller should first await
  /// the `serviceConnection.serviceManager.onServiceAvailable` future to ensure the service has
  /// been initialized.
  /// The controller does not need to handle re-connection to the application. When reconnected,
  /// DevTools will create a new controller. However, the controller should make sure
  /// not to fail if the connection is lost.
  final C Function(DevToolsRouterDelegate)? createController;

  /// Returns true if a controller was provided for [screen]. If false,
  /// [screen] is responsible for creating and maintaining its own controller.
  bool get providesController => createController != null;

  Provider<C> controllerProvider(DevToolsRouterDelegate routerDelegate) {
    return Provider<C>(
      create: (_) {
        final controller = createController!(routerDelegate);
        if (controller is OfflineScreenControllerMixin) {
          controller.initReviewHistoryOnDisconnectListener();
        }
        return controller;
      },
    );
  }
}

/// A [WidgetBuilder] that takes an additional map of URL query parameters and
/// args, as well a state not included in the URL.
typedef UrlParametersBuilder = Widget Function(
  BuildContext,
  String?,
  DevToolsQueryParams,
  DevToolsNavigationState?,
);

/// Displays the checked mode banner in the bottom end corner instead of the
/// top end corner.
///
/// This avoids issues with widgets in the appbar being hidden by the banner
/// in a web or desktop app.
class _AlternateCheckedModeBanner extends StatelessWidget {
  const _AlternateCheckedModeBanner({required this.builder});
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

class PageNotFound extends StatelessWidget {
  const PageNotFound({
    super.key,
    required this.page,
    required this.routerDelegate,
  });

  final String page;

  final DevToolsRouterDelegate routerDelegate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("'$page' not found."),
          const SizedBox(height: defaultSpacing),
          ElevatedButton(
            onPressed: () =>
                routerDelegate.navigateHome(clearScreenParam: true),
            child: const Text('Go to Home screen'),
          ),
        ],
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
    ),
    DevToolsScreen<ProfilerScreenController>(
      ProfilerScreen(),
      createController: (_) => ProfilerScreenController(),
    ),
    DevToolsScreen<MemoryController>(
      MemoryScreen(),
      createController: (_) => MemoryController(),
    ),
    DevToolsScreen<DebuggerController>(
      DebuggerScreen(),
      createController: (routerDelegate) => DebuggerController(
        routerDelegate: routerDelegate,
      ),
    ),
    DevToolsScreen<NetworkController>(
      NetworkScreen(),
      createController: (_) => NetworkController(),
    ),
    FeatureFlags.loggingV2
        ? DevToolsScreen<LoggingControllerV2>(
            LoggingScreenV2(),
            createController: (_) => LoggingControllerV2(),
          )
        : DevToolsScreen<LoggingController>(
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
      ),
  ];
}

@visibleForTesting
List<DevToolsScreen>? devtoolsScreens;
