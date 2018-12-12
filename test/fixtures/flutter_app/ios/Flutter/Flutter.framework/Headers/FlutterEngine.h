// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FLUTTERENGINE_H_
#define FLUTTER_FLUTTERENGINE_H_

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "FlutterBinaryMessenger.h"
#include "FlutterDartProject.h"
#include "FlutterMacros.h"
#include "FlutterPlugin.h"
#include "FlutterTexture.h"

@class FlutterViewController;

/**
 * The FlutterEngine class coordinates a single instance of execution for a
 * `FlutterDartProject`.  It may have zero or one `FlutterViewController` at a
 * time, which can be specified via `-setViewController:`.
 * `FlutterViewController`'s `initWithEngine` initializer will automatically call
 * `-setViewController:` for itself.
 *
 * A FlutterEngine can be created independently of a `FlutterViewController` for
 * headless execution.  It can also persist across the lifespan of multiple
 * `FlutterViewController` instances to maintain state and/or asynchronous tasks
 * (such as downloading a large file).
 *
 * Alternatively, you can simply create a new `FlutterViewController` with only a
 * `FlutterDartProject`. That `FlutterViewController` will internally manage its
 * own instance of a FlutterEngine, but will not guarantee survival of the engine
 * beyond the life of the ViewController.
 *
 * A newly initialized FlutterEngine will not actually run a Dart Isolate until
 * either `-runWithEntrypoint:` or `-runWithEntrypoint:libraryURI` is invoked.
 * One of these methods must be invoked before calling `-setViewController:`.
 */
FLUTTER_EXPORT
@interface FlutterEngine
    : NSObject <FlutterBinaryMessenger, FlutterTextureRegistry, FlutterPluginRegistry>
/**
 * Initialize this FlutterEngine with a `FlutterDartProject`.
 *
 * If the FlutterDartProject is not specified, the FlutterEngine will attempt to locate
 * the project in a default location (the flutter_assets folder in the iOS application
 * bundle).
 *
 * A newly initialized engine will not run the `FlutterDartProject` until either
 * `-runWithEntrypoint:` or `-runWithEntrypoint:libraryURI:` is called.
 *
 * @param labelPrefix The label prefix used to identify threads for this instance. Should
 *   be unique across FlutterEngine instances, and is used in instrumentation to label
 *   the threads used by this FlutterEngine.
 * @param projectOrNil The `FlutterDartProject` to run.
 */
- (instancetype)initWithName:(NSString*)labelPrefix
                     project:(FlutterDartProject*)projectOrNil NS_DESIGNATED_INITIALIZER;

/**
 * The default initializer is not available for this object.
 * Callers must use `-[FlutterEngine initWithName:project:]`.
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Runs a Dart program on an Isolate from the main Dart library (i.e. the library that
 * contains `main()`).
 *
 * The first call to this method will create a new Isolate. Subsequent calls will return
 * immediately.
 *
 * @param entrypoint The name of a top-level function from the same Dart
 *   library that contains the app's main() function.  If this is nil, it will
 *   default to `main()`.  If it is not the app's main() function, that function
 *   must be decorated with `@pragma(vm:entry-point)` to ensure the method is not
 *   tree-shaken by the Dart compiler.
 * @return YES if the call succeeds in creating and running a Flutter Engine instance; NO otherwise.
 */
- (BOOL)runWithEntrypoint:(NSString*)entrypoint;

/**
 * Runs a Dart program on an Isolate using the specified entrypoint and Dart library,
 * which may not be the same as the library containing the Dart program's `main()` function.
 *
 * The first call to this method will create a new Isolate. Subsequent calls will return
 * immediately.
 *
 * @param entrypoint The name of a top-level function from a Dart library.  If nil, this will
 *   default to `main()`.  If it is not the app's main() function, that function
 *   must be decorated with `@pragma(vm:entry-point)` to ensure the method is not
 *   tree-shaken by the Dart compiler.
 * @param uri The URI of the Dart library which contains the entrypoint method.  IF nil,
 *   this will default to the same library as the `main()` function in the Dart program.
 * @return YES if the call succeeds in creating and running a Flutter Engine instance; NO otherwise.
 */
- (BOOL)runWithEntrypoint:(NSString*)entrypoint libraryURI:(NSString*)uri;

/**
 * Sets the `FlutterViewController` for this instance.  The FlutterEngine must be
 * running (e.g. a successful call to `-runWithEntrypoint:` or `-runWithEntrypoint:libraryURI`)
 * before calling this method. Callers may pass nil to remove the viewController
 * and have the engine run headless in the current process.
 *
 * A FlutterEngine can only have one `FlutterViewController` at a time. If there is
 * already a `FlutterViewController` associated with this instance, this method will replace
 * the engine's current viewController with the newly specified one.
 *
 * Setting the viewController will signal the engine to start animations and drawing, and unsetting
 * it will signal the engine to stop animations and drawing.  However, neither will impact the state
 * of the Dart program's execution.
 */
@property(nonatomic, weak) FlutterViewController* viewController;

/**
 * The `FlutterMethodChannel` used for localization related platform messages, such as
 * setting the locale.
 */
@property(nonatomic, readonly) FlutterMethodChannel* localizationChannel;
/**
 * The `FlutterMethodChannel` used for navigation related platform messages.
 *
 * @see [Navigation
 * Channel](https://docs.flutter.io/flutter/services/SystemChannels/navigation-constant.html)
 * @see [Navigator Widget](https://docs.flutter.io/flutter/widgets/Navigator-class.html)
 */
@property(nonatomic, readonly) FlutterMethodChannel* navigationChannel;

/**
 * The `FlutterMethodChannel` used for core platform messages, such as
 * information about the screen orientation.
 */
@property(nonatomic, readonly) FlutterMethodChannel* platformChannel;

/**
 * The `FlutterMethodChannel` used to communicate text input events to the
 * Dart Isolate.
 *
 * @see [Text Input
 * Channel](https://docs.flutter.io/flutter/services/SystemChannels/textInput-constant.html)
 */
@property(nonatomic, readonly) FlutterMethodChannel* textInputChannel;

/**
 * The `FlutterBasicMessageChannel` used to communicate app lifecycle events
 * to the Dart Isolate.
 *
 * @see [Lifecycle
 * Channel](https://docs.flutter.io/flutter/services/SystemChannels/lifecycle-constant.html)
 */
@property(nonatomic, readonly) FlutterBasicMessageChannel* lifecycleChannel;

/**
 * The `FlutterBasicMessageChannel` used for communicating system events, such as
 * memory pressure events.
 *
 * @see [System
 * Channel](https://docs.flutter.io/flutter/services/SystemChannels/system-constant.html)
 */
@property(nonatomic, readonly) FlutterBasicMessageChannel* systemChannel;

/**
 * The `FlutterBasicMessageChannel` used for communicating user settings such as
 * clock format and text scale.
 */
@property(nonatomic, readonly) FlutterBasicMessageChannel* settingsChannel;

@end

#endif  // FLUTTER_FLUTTERENGINE_H_
