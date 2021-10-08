// The content of the addServiceExtensions method from this file is executed as
// if it was part of the package:flutter/src/widgets/widget_inspector.dart
// library to register additional dart:developer service extensions useful for
// devtools that are not defined in package:flutter for all versions of
// package:flutter that devtools needs to support.
//
// Using this library solves the problem that a single version of DevTools
// should support a wide range of package:flutter versions and that new DevTools
// features should be exposed with a wide range of Flutter versions to get
// useful user feedback.
//
// We currently execute this library using eval but that should be viewed as an
// implementation detail as eval is simply the most expedient way to currently
// late bind these service extensions. It could make sense to provide an
// alternate eval like mechanism to inject additional libraries into an already
// running Dart application. For example, the fact that we cannot define
// additional classes using eval is a little limiting to what we can do within
// this polyfill.
//
// Only code between the INSPECTOR_POLYFILL_SCRIPT_START and
// the INSPECTOR_POLYFILL_SCRIPT_END tags are actually executed. All other code
// exists purely to get consistent static warnings with what would be displayed
// when this code is evaluated in the context of
// package:flutter/src/widgets/widget_inspector.dart
//
// The imports in this file intentionally match the imports specified by
// package:flutter/src/widgets/widget_inspector.dart so that we get consistent
// static warnings and autocompletes while editing this file. Do not add
// additional imports to this file.
// ignore_for_file: unused_import

// This code needs to execute both in null safe and legacy versions of Dart
// so it needs to be written in a way that is null safe without depending on any
// of the new null safety syntax. To test that this script works with null safe
// dart, edit the analysis_options file to enable null safety.
// If supporting null safe and legacy Dart at the same time becomes too
// difficult, we can fork this file and provide two polyfill scripts one for the
// legacy and one for the null safe versions of Dart.
// We must suppress unnecessary cast lints as the casts are necessary in
// null safe dart but the devtools_app library has not yet been migrated.
// ignore_for_file: unnecessary_cast

// Code from this class is executed within the context of the
// widget_inspector.dart library so using protected members is fine.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui
    show
        ClipOp,
        Image,
        ImageByteFormat,
        Paragraph,
        Picture,
        PictureRecorder,
        PointMode,
        SceneBuilder,
        Vertices;
import 'dart:ui' show Canvas, Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/src/widgets/app.dart';
import 'package:flutter/src/widgets/binding.dart';
import 'package:flutter/src/widgets/debug.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/gesture_detector.dart';
import 'package:flutter/src/widgets/widget_inspector.dart';
import 'package:vector_math/vector_math_64.dart';

// This extension method is simply a hack to make a private member defined on
// WidgetInspectorService show up as in scope as far as the analysis server is
// concerned.
extension WidgetInspectorServicePrivateMethods on WidgetInspectorService {
  Map<String, Object /*?*/ > /*?*/ _nodeToJson(
    DiagnosticsNode /*?*/ node,
    InspectorSerializationDelegate delegate,
  ) {
    throw 'Dummy extension method to make the code type check when it calls private members';
  }

  String _safeJsonEncode(Object object) {
    throw 'Dummy extension method to make the code type check when it calls private members';
  }

  List<String> /*?*/ get _pubRootDirectories {
    throw 'Dummy extension method to make the code type check when it calls private members';
  }
}

// Returns json describing which service extensions failed to load.
//
// The format of the json is:
// {'extension_name_a': 'exception message_a', 'extension_name_b', 'exception_message_b', ...}
String addServiceExtensions() {
  // INSPECTOR_POLYFILL_SCRIPT_START
  T toEnumEntry<T>(List<T> enumEntries, String name) {
    for (T entry in enumEntries) {
      if (entry.toString() == name) {
        return entry;
      }
    }
    throw 'Enum value $name not found';
  }

  /// This is identical to Flutter's getRootWidgetSummaryTree service extension,
  /// but with the added properties.
  Future<Map<String, dynamic>> getRootWidgetSummaryTreeWithPreviews(
      Map<String, String> parameters) {
    final instance = WidgetInspectorService.instance;
    final groupName = parameters['groupName'];

    final result = instance._nodeToJson(
      WidgetsBinding.instance?.renderViewElement?.toDiagnosticsNode(),
      InspectorSerializationDelegate(
        groupName: groupName,
        subtreeDepth: 1000000,
        summaryTree: true,
        service: instance,
        addAdditionalPropertiesCallback: (DiagnosticsNode node, delegate) {
          final additionalJson = <String, Object>{};

          final value = node.value;
          if (value is Element) {
            final renderObject = value.renderObject;
            if (renderObject is RenderParagraph) {
              additionalJson['textPreview'] = renderObject.text.toPlainText();
            }
          }

          return additionalJson;
        },
      ),
    );

    return Future.value(<String, dynamic>{
      'result': result,
    });
  }

  Future<Map<String, dynamic>> getLayoutExplorerNode(
      Map<String, String> parameters) {
    final id = parameters['id'];
    final subtreeDepth = int.parse(parameters['subtreeDepth'] as String);
    final groupName = parameters['groupName'];
    var result = <String, dynamic>{};
    final instance = WidgetInspectorService.instance;
    final root = instance.toObject(id);
    if (root == null) {
      return Future.value(<String, dynamic>{
        'result': result,
      });
    }
    result = instance._nodeToJson(
      root as DiagnosticsNode,
      InspectorSerializationDelegate(
          groupName: groupName,
          summaryTree: true,
          subtreeDepth: subtreeDepth,
          service: instance,
          addAdditionalPropertiesCallback: (node, delegate) {
            final Map<String, Object> additionalJson = <String, Object>{};
            final value = node.value;
            if (value is Element) {
              final renderObject = value.renderObject;
              if (renderObject != null) {
                additionalJson['renderObject'] =
                    renderObject.toDiagnosticsNode().toJsonMap(
                          delegate.copyWith(
                            subtreeDepth: 0,
                            includeProperties: true,
                          ),
                        ) as Object;

                final renderParent = renderObject.parent;
                if (renderParent is RenderObject && subtreeDepth > 0) {
                  final parentCreator = renderParent.debugCreator;
                  if (parentCreator is DebugCreator) {
                    additionalJson['parentRenderElement'] =
                        parentCreator.element.toDiagnosticsNode().toJsonMap(
                              delegate.copyWith(
                                subtreeDepth: 0,
                                includeProperties: true,
                              ),
                            ) as Object;
                    // TODO(jacobr): also describe the path back up the tree to
                    // the RenderParentElement from the current element. It
                    // could be a surprising distance up the tree if a lot of
                    // elements don't have their own RenderObjects.
                  }
                }

                try {
                  if (!renderObject.debugNeedsLayout) {
                    final constraints = renderObject.constraints;
                    final constraintsProperty = <String, Object>{
                      'type': constraints.runtimeType.toString(),
                      'description': constraints.toString(),
                    };
                    if (constraints is BoxConstraints) {
                      constraintsProperty.addAll(<String, Object>{
                        'minWidth': constraints.minWidth.toString(),
                        'minHeight': constraints.minHeight.toString(),
                        'maxWidth': constraints.maxWidth.toString(),
                        'maxHeight': constraints.maxHeight.toString(),
                      });
                    }
                    additionalJson['constraints'] = constraintsProperty;
                  }
                } catch (e) {
                  // Constraints are sometimes unavailable even though
                  // debugNeedsLayout is false.
                }

                try {
                  if (renderObject is RenderBox) {
                    additionalJson['isBox'] = true;
                    additionalJson['size'] = <String, Object>{
                      'width': renderObject.size.width.toString(),
                      'height': renderObject.size.height.toString(),
                    };

                    final parentData = renderObject.parentData;
                    if (parentData is FlexParentData) {
                      additionalJson['flexFactor'] = parentData.flex as int;
                      additionalJson['flexFit'] =
                          describeEnum(parentData.fit ?? FlexFit.tight);
                    } else if (parentData is BoxParentData) {
                      final offset = parentData.offset;
                      additionalJson['parentData'] = {
                        'offsetX': offset.dx.toString(),
                        'offsetY': offset.dy.toString(),
                      };
                    }
                  } else if (renderObject is RenderView) {
                    additionalJson['size'] = <String, Object>{
                      'width': renderObject.size.width.toString(),
                      'height': renderObject.size.height.toString(),
                    };
                  }
                } catch (e) {
                  // Not laid out yet.
                }
              }
            }
            return additionalJson;
          }),
    ) as Map<String, dynamic>;
    return Future.value(<String, dynamic>{
      'result': result,
    });
  }

  Future<Map<String, dynamic>> setFlexFit(Map<String, String> parameters) {
    final String id = parameters['id'] as String;
    final parameter = parameters['flexFit'] as String;
    final FlexFit flexFit = toEnumEntry<FlexFit>(FlexFit.values, parameter);
    final dynamic object = WidgetInspectorService.instance.toObject(id);
    bool succeed = false;
    if (object != null) {
      final render = object.renderObject;
      final parentData = render.parentData;
      if (parentData is FlexParentData) {
        parentData.fit = flexFit;
        render.markNeedsLayout();
        succeed = true;
      }
    }
    return Future.value(<String, Object>{
      'result': succeed,
    });
  }

  Future<Map<String, dynamic>> setFlexFactor(Map<String, String> parameters) {
    final String id = parameters['id'] as String;
    final String flexFactor = parameters['flexFactor'] as String;
    final factor = flexFactor == 'null' ? null : int.parse(flexFactor);
    final dynamic object = WidgetInspectorService.instance.toObject(id);
    bool succeed = false;
    if (object != null) {
      final render = object.renderObject;
      final parentData = render.parentData;
      if (parentData is FlexParentData) {
        parentData.flex = factor;
        render.markNeedsLayout();
        succeed = true;
      }
    }
    return Future.value({'result': succeed});
  }

  Future<Map<String, dynamic>> setFlexProperties(
      Map<String, String> parameters) {
    final String id = parameters['id'] as String;
    final MainAxisAlignment mainAxisAlignment = toEnumEntry<MainAxisAlignment>(
      MainAxisAlignment.values,
      parameters['mainAxisAlignment'] as String,
    );
    final CrossAxisAlignment crossAxisAlignment =
        toEnumEntry<CrossAxisAlignment>(
      CrossAxisAlignment.values,
      parameters['crossAxisAlignment'] as String,
    );
    final dynamic object = WidgetInspectorService.instance.toObject(id);
    bool succeed = false;
    if (object != null) {
      final render = object.renderObject;
      if (render is RenderFlex) {
        render.mainAxisAlignment = mainAxisAlignment;
        render.crossAxisAlignment = crossAxisAlignment;
        render.markNeedsLayout();
        render.markNeedsPaint();
        succeed = true;
      }
    }
    return Future.value(<String, Object>{'result': succeed});
  }

  Future<Map<String, dynamic>> getPubRootDirectories(
    Map<String, String> parameters,
  ) {
    return Future.value(<String, Object>{
      'result': WidgetInspectorService.instance._pubRootDirectories ?? [],
    });
  }

  final failures = <String, String>{};
  void registerHelper(String name, ServiceExtensionCallback callback) {
    try {
      WidgetInspectorService.instance.registerServiceExtension(
        name: name,
        callback: callback,
      );
    } catch (e) {
      // It is not a fatal error if some of the extensions fail to register
      // as could be the case if some are already defined directly within
      // package:flutter for the version of package:flutter being used.
      failures[name] = e.toString();
    }
  }

  registerHelper('getLayoutExplorerNode', getLayoutExplorerNode);
  registerHelper('setFlexFit', setFlexFit);
  registerHelper('setFlexFactor', setFlexFactor);
  registerHelper('setFlexProperties', setFlexProperties);
  registerHelper('getPubRootDirectories', getPubRootDirectories);
  registerHelper(
    'getRootWidgetSummaryTreeWithPreviews',
    getRootWidgetSummaryTreeWithPreviews,
  );

  return WidgetInspectorService.instance._safeJsonEncode(failures);
  // INSPECTOR_POLYFILL_SCRIPT_END
}
