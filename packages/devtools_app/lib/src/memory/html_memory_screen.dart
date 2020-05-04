// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:html' as html;

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart';
import '../framework/html_framework.dart';
import '../globals.dart';
import '../html_popup.dart';
import '../html_tables.dart';
import '../table_data.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/html_custom.dart';
import '../ui/html_elements.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/ui_utils.dart';
import '../utils.dart';
import 'html_memory_chart.dart';
import 'html_memory_data_view.dart';
import 'html_memory_inbounds.dart';
import 'memory_controller.dart';
import 'memory_detail.dart';
import 'memory_protocol.dart';
import 'memory_service.dart';

const memoryScreenId = 'memory';

class HtmlMemoryScreen extends HtmlScreen with HtmlSetStateMixin {
  HtmlMemoryScreen({bool enabled, String disabledTooltip, this.isProfileBuild})
      : super(
          name: 'Memory',
          id: memoryScreenId,
          iconClass: 'octicon-package',
          enabled: enabled,
          disabledTooltip: disabledTooltip,
        ) {
    // Hookup for memory UI short-cut keys.
    shortcutCallback = memoryShortcuts;

    classCountStatus = HtmlStatusItem();
    addStatusItem(classCountStatus);

    objectCountStatus = HtmlStatusItem();
    addStatusItem(objectCountStatus);

    experimentStatus = HtmlStatusItem();
    addStatusItem(experimentStatus);
  }

  final MemoryController memoryController = MemoryController();

  CoreElement settings;
  CoreElement librariesUi;

  HtmlStatusItem classCountStatus;

  HtmlStatusItem objectCountStatus;

  HtmlStatusItem experimentStatus;

  PButton pauseButton;

  PButton resumeButton;

  /// The autocomplete view manages the textfield and popup list.
  CoreElement vmSearchField;

  HtmlPopupListView<String> heapPopupList;

  HtmlPopupAutoCompleteView heapAutoCompletePopup;

  /// Hover card shows where allocation occurred and references to instance.
  final CoreElement hoverPopup = div(c: 'allocation-hover-card');

  PButton vmMemorySearchButton;

  PButton vmMemorySnapshotButton;

  PButton resetAccumulatorsButton;

  PButton settingsButton;

  PButton gcNowButton;

  ListQueue<HtmlTable<dynamic>> tableStack = ListQueue<HtmlTable<dynamic>>();

  HtmlMemoryChart memoryChart;

  CoreElement tableContainer;

  List<ClassHeapDetailStats> originalHeapStats;

  HtmlInboundsTree _inboundTree;

  /// Memory navigation history. Driven from selecting items in the list of
  /// known classes, instances of a particular class and clicking on the class
  /// and field that allocated the instance (holds the reference).
  /// This list is displayed as a set of hyperlinks e.g.,
  ///
  ///     class1 (instance) > class2.extra > class3.mainHolder
  ///     -----------------   ------------   -----------------
  ///
  /// Clicking on one of the above links would select the class and instance that
  /// was associated with that hover navigation.  In this case:
  ///    [class3.mainHolder] - class3 called class2 constructor storing the
  ///                          reference to class2 in the field mainHolder.
  ///    [class2.extra]      - class2 called class1 constructor and stored the
  ///                          reference to class1 in field extra.
  CoreElement history;

  /// This remembers how memory was navigated using the hover card to render the
  /// links in the history element (see above).
  NavigationPath memoryPath = NavigationPath();

  /// Signals if navigation is happening as a result of clicking in a hover card.
  /// If true, keep recording the navigation instead of resetting history.
  bool fromMemoryHover = false;

  HtmlMemoryDataView memoryDataView;

  MemoryTracker memoryTracker;

  HtmlProgressElement progressElement;

  // TODO(terry): Remove experiment after binary snapshot is added.
  bool get isMemoryExperiment =>
      memoryController.settings.experiment && !isProfileBuild;

  final bool isProfileBuild;

  /// Handle shortcut keys
  bool memoryShortcuts(bool ctrlKey, bool shiftKey, bool altKey, String key) {
    if (ctrlKey && key == 'f') {
      _search();
      return true;
    }
    return false;
  }

  @override
  void entering() {
    _updateListeningState();
  }

  void updateResumeButton({@required bool disabled}) {
    resumeButton.disabled = disabled;
  }

  void updatePauseButton({@required bool disabled}) {
    pauseButton.disabled = disabled;
  }

  @override
  CoreElement createContent(HtmlFramework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    resumeButton = PButton.icon('Resume', FlutterIcons.resume_white_disabled_2x)
      ..primary()
      ..small()
      ..disabled = true;

    pauseButton = PButton.icon('Pause', FlutterIcons.pause_black_2x)..small();

    heapPopupList = HtmlPopupListView<String>();

    vmSearchField = CoreElement('input', classes: 'search-text')
      ..setAttribute('type', 'text')
      ..setAttribute('placeholder', 'search')
      ..id = 'popup_search_memory';
    vmMemorySearchButton =
        PButton.icon('', FlutterIcons.search, title: 'Memory Search')
          ..small()
          ..click(_search)
          ..disabled = true;
    // TODO(terry): Need to correctly handle enabled and disabled.
    vmMemorySnapshotButton = PButton.icon('Snapshot', FlutterIcons.snapshot,
        title: 'Memory Snapshot')
      ..clazz('margin-left')
      ..small()
      ..click(
        _loadAllocationProfile,
        () {
          // Shift key pressed while clicking on Snapshot button enables live
          // memory inspection will not work in profile build.

          // TODO(terry): Disable when real binary snapshot is exposed.
          enableExperiment();

          _loadAllocationProfile();
        },
      )
      ..disabled = true;
    resetAccumulatorsButton = PButton.icon(
        'Reset', FlutterIcons.resetAccumulators,
        title: 'Reset Accumulators')
      ..small()
      ..click(_resetAllocatorCounts)
      ..disabled = true;
    heapAutoCompletePopup = HtmlPopupAutoCompleteView(
      heapPopupList,
      screenDiv,
      vmSearchField,
      _callbackPopupSelectClass,
    );
    gcNowButton =
        PButton.icon('GC', FlutterIcons.gcNow, title: 'Manual Garbage Collect')
          ..small()
          ..click(_gcNow)
          ..disabled = true;
    settingsButton = PButton.icon('', FlutterIcons.settings, title: 'Settings')
      ..small()
      ..click(_displaySettingsDialog)
      ..disabled = true;

    resumeButton.click(() {
      ga.select(ga.memory, ga.resume);

      updateResumeButton(disabled: true);
      updatePauseButton(disabled: false);

      memoryChart.resume();
    });

    pauseButton.click(() {
      ga.select(ga.memory, ga.pause);

      updatePauseButton(disabled: true);
      updateResumeButton(disabled: false);

      memoryChart.pause();
    });

    // Handle keeping card active while mouse in the hover card.
    hoverPopup.onMouseOver.listen((html.MouseEvent evt) {
      _mouseInHover(evt);
    });

    // Handle hiding card once mouse is outside of the hover card.
    hoverPopup.onMouseLeave.listen((html.MouseEvent evt) {
      _mouseOutHover(evt);
    });

    history = div(c: 'history-navigation section', a: 'hidden');

    createSettingsDialog();

    screenDiv.add(<CoreElement>[
      settings..element.style.display = 'none',
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..layoutHorizontal()
            ..clazz('align-items-center')
            ..add(<CoreElement>[
              div(c: 'btn-group collapsible-885 flex-no-wrap')
                ..add(<CoreElement>[
                  pauseButton,
                  resumeButton,
                ]),
              div()..flex(),
              div(
                  c: 'btn-group collapsible-785 nowrap margin-left '
                      'memory-buttons')
                ..flex()
                ..add(<CoreElement>[
                  vmSearchField,
                  vmMemorySearchButton,
                  vmMemorySnapshotButton,
                  resetAccumulatorsButton,
                  gcNowButton,
                  settingsButton,
                ]),
            ]),
        ]),
      memoryChart = HtmlMemoryChart(memoryController)..disabled = true,
      tableContainer = div(c: 'section overflow-auto')
        ..layoutHorizontal()
        ..flex(),
      history,
      heapAutoCompletePopup,
      hoverPopup, // Hover card
    ]);

    memoryController.onDisconnect.listen((__) {
      serviceDisconnect();
    });

    maybeAddDebugMessage(framework, memoryScreenId);

    _pushNextTable(null, _createHeapStatsTableView());

    _updateStatus(null);

    vmMemorySnapshotButton.disabled = true;

    memoryController.computeLibraries().then((_) {
      // Enable snapshot/setting buttons, all libraries and classses have been
      // processed.
      vmMemorySnapshotButton.disabled = false;
      settingsButton.disabled = false;
    });

    return screenDiv;
  }

  TextField classNameFilter;

  List<CoreElement> privateClasses;

  List<CoreElement> experimentCheckbox;

  /// Create the settings dialog.
  void createSettingsDialog() {
    settings = div(c: 'section settings-box')
      ..add(<CoreElement>[
        h2(text: 'Settings', c: 'settings-title'),
        div(c: 'settings-area')
          ..add(<CoreElement>[
            form()
              ..layoutHorizontal()
              ..clazz('align-items-center')
              ..add(<CoreElement>[
                div(
                  text: 'Display Snapshot Classes from Library',
                  c: 'collapsible-885 flex-no-wrap settings-left',
                )..add([
                    librariesUi = div(c: 'settings-libraries'),
                  ]),
                div(c: 'setttings-options')
                  ..add([
                    div(c: 'filter-pattern-area')
                      ..add(<CoreElement>[
                        span(
                          text: 'Class Filter: ',
                          c: 'settings-class-pattern',
                        ),
                        classNameFilter = TextField(c: 'filter-class')
                          ..value = memoryController.settings.pattern
                          ..changed(_classPatternChanged)
                          ..setAttribute('placeholder', 'Any'),
                        br(),
                      ]),
                  ]
                    ..addAll(privateClasses = createCheckBox(
                      'Hide Private Classes ',
                      memoryController.settings.hidePrivateClasses,
                      _liveUpdateFilters,
                    ))
                    ..addAll([
                      br(), // Filter Option 3 available
                      br(), // Filter Option 4 available
                      br(), // Filter Option 5 available
                    ])),
                div(c: 'setttings-options-2')
                  ..add([
                    experimentCheckbox = createCheckBox(
                        'Navigation Experiment ',
                        memoryController.settings.experiment, () {
                      // TODO(terry): Brittle but experiments for now.
                      final html.CheckboxInputElement cb =
                          experimentCheckbox.first.element;
                      memoryController.settings.experiment = cb.checked;
                    }),
                    br(), // Settings Option 2 available
                    br(), // Settings Option 3 available
                    br(), // Settings Option 4 available
                    br(), // Settings Option 5 available
                    br(), // Settings Option 6 available
                  ]),
                div()..flex(),
                div(
                  c: 'settings-buttons btn-group collapsible-785 '
                      'nowrap margin-left text-right',
                )
                  ..flex()
                  ..add(<CoreElement>[
                    PButton('Apply')..click(_applySettings),
                    PButton('Cancel')..click(_cancelSettings),
                  ]),
              ]),
          ]),
      ]);

    // The memory experiement is not available in profile mode.
    experimentCheckbox.first.disabled = isProfileBuild;
  }

  void enableExperiment() {
    memoryController.settings.experiment = true;
    final html.CheckboxInputElement cb = experimentCheckbox.first.element;
    cb.checked = true;
  }

  void _displaySettingsDialog() {
    // Gray Filter button while dialog is up - only apply/cancel can close.
    settingsButton.disabled = true;

    librariesUi.add(createLibrariesUi());
    settings.element.style.display = 'block';

    // Set focus to filter pattern field.
    classNameFilter.element.focus();
  }

  void _classPatternChanged(String value) {
    _liveUpdateFilters();
  }

  /// Update the classes table (if snapshot) live.
  void _liveUpdateFilters() {
    final pattern = classNameFilter.value != null ? classNameFilter.value : '';

    final html.InputElement checkbox = privateClasses.first.element;

    final tempFilters = FilteredLibraries()..clearFilters();

    final librariesChecked = librariesUi.element.children;
    for (final element in librariesChecked) {
      if (element.tagName == 'INPUT' &&
          element.attributes['type'] == 'checkbox') {
        final html.InputElement checkbox = element;
        if (!checkbox.checked) {
          tempFilters.addFilter(checkbox.value);
        }
      }
    }

    // Immediately re-compute classes to update the current classes snapshot.
    memoryController.libraryCollection.computeDisplayClasses(tempFilters);

    _displayClassesSnapshot(
      classPattern: pattern,
      hidePrivates: checkbox.checked,
    );
  }

  void _applySettings() {
    // Recompute the libraries that are filtered.
    memoryController.libraryFilters.clearFilters();

    final librariesChecked = librariesUi.element.children;
    for (final element in librariesChecked) {
      if (element.tagName == 'INPUT' &&
          element.attributes['type'] == 'checkbox') {
        final html.InputElement checkbox = element;
        if (!checkbox.checked) {
          memoryController.libraryFilters.addFilter(checkbox.value);
        }
      }
    }

    // Only update displayClasses no need to recompute the snapshot display.
    // This was already done with live updating (as checkboxes were clicked).
    memoryController.libraryCollection.computeDisplayClasses();

    librariesUi.element.children.clear();

    memoryController.settings.pattern = classNameFilter.value;

    // Is private class names _NNNN hidden
    final html.CheckboxInputElement hidePrivate = privateClasses.first.element;
    memoryController.settings.hidePrivateClasses = hidePrivate.checked;

    // Display experiment checkbox, if the memory experiment is enabled.
    final html.CheckboxInputElement checkbox = experimentCheckbox.first.element;
    memoryController.settings.experiment = checkbox.checked;

    _closeSettingsDialog();
  }

  void _cancelSettings() {
    // Undo the live updates user wants to cancel the what ifs.
    memoryController.libraryCollection
        .computeDisplayClasses(memoryController.libraryFilters);
    _displayClassesSnapshot(
      classPattern: memoryController.settings.pattern,
      hidePrivates: memoryController.settings.hidePrivateClasses,
    );

    librariesUi.element.children.clear();
    _closeSettingsDialog();
  }

  void _closeSettingsDialog() {
    settings.element.style.display = 'none';

    settingsButton.disabled = false;
  }

  List<CoreElement> createCheckBox(String name, bool checked, void handle()) =>
      [
        checkbox(
          text: name,
          c: 'settings-checkbox-option',
          a: checked ? 'checked' : null,
        )
          ..setAttribute('name', name)
          ..setAttribute('value', name)
          ..click(handle),
        label(text: name, c: 'settings-checkbox-label-option')
          ..setAttribute('for', name),
        br()
      ];

  List<CoreElement> createLibraryEntry(String name, [bool checked = true]) => [
        checkbox(
            text: name,
            c: 'settings-libraries-checkbox',
            a: checked ? 'checked' : null)
          ..setAttribute('id', name)
          ..setAttribute('value', name)
          ..click(_liveUpdateFilters),
        label(text: name, c: 'settings-libraries-label')
          ..setAttribute('for', name),
        br()
      ];

  /// Create all library entries in the list box.
  List<CoreElement> createLibrariesUi() {
    final List<CoreElement> libraryUiItems = [];

    final sortedLibraries = memoryController.sortLibrariesByNormalizedNames();
    String lastLibraryDisplayed = '';
    for (var normalizedName in sortedLibraries) {
      if (normalizedName != lastLibraryDisplayed) {
        libraryUiItems.addAll(createLibraryEntry(
            normalizedName,
            !memoryController.libraryFilters
                .isLibraryFiltered(normalizedName)));
        lastLibraryDisplayed = normalizedName;
      }
    }

    return libraryUiItems;
  }

  ClassHeapDetailStats findClass(String className) {
    final List<ClassHeapDetailStats> classesData = tableStack.first.model.data;
    return classesData.firstWhere(
      (stat) => stat.classRef.name == className,
      orElse: () => null,
    );
  }

  Future<List<InstanceSummary>> findInstances(ClassHeapDetailStats row) async {
    try {
      final List<InstanceSummary> instances =
          await memoryController.getInstances(
        row.classRef.id,
        row.classRef.name,
        row.instancesCurrent,
      );

      return instances;
    } catch (e) {
      // TODO(terry): Cleanup error.
      log('findInstances: $e', LogLevel.error);
      return [];
    }
  }

  ClassHeapDetailStats findClassDetails(String classRefId) {
    final List<ClassHeapDetailStats> classesData = tableStack.first.model.data;
    return classesData.firstWhere(
      (stat) => stat.classRef.id == classRefId,
      orElse: () => null,
    );
  }

  void _selectClass(String className, {bool record = true}) {
    final List<ClassHeapDetailStats> classesData = tableStack.first.model.data;
    int row = 0;
    for (ClassHeapDetailStats stat in classesData) {
      if (stat.classRef.name == className) {
        tableStack.first.selectByIndex(row, scrollBehavior: 'auto');
        if (record) {
          memoryPath.add(NavigationState.classSelect(className));
        }
        return;
      }
      row++;
    }

    framework.toast('Unable to find class $className', title: 'Error');
  }

  Future<int> _selectInstanceInFieldHashCode(
      String fieldName, int instanceHashCode) async {
    final HtmlTable<Object> instanceTable = tableStack.elementAt(1);
    final spinner = HtmlSpinner.centered();
    instanceTable.element.add(spinner);

    // There's an instances table up.
    // TODO(terry): Need more efficient way to match ObjectRefs than hashCodes.
    final List<InstanceSummary> instances = instanceTable.model.data;
    int row = 0;
    for (InstanceSummary instance in instances) {
      // Check the field in each instance looking to find the object being held
      // (the hashCode passed in matches the particular field's hashCode)

      // TODO(terry): Enable below once expressions accessing private fields
      // TODO(terry): e.g., _extra.hashCode works again.  Better yet code that
      // TODO(terry): is more efficient that allows objectRef identity.
      //
      // final evalResult = await evaluate(instance.objectRef, '$fieldName.hashCode');
      // int fieldHashCode =
      //     evalResult != null ? int.parse(evalResult.valueAsString) : null;
      //
      // if (fieldHashCode == instanceHashCode) {
      //   // Found the object select the instance.
      //   instanceTable.selectByIndex(row, scrollBehavior: 'auto');
      //   spinner.remove();
      //   return row;
      // }

      // TODO(terry): Temporary workaround since evaluate fails on expressions
      // TODO(terry): accessing a private field e.g., _extra.hashcode.
      if (await memoryController.matchObject(
          instance.objectRef, fieldName, instanceHashCode)) {
        instanceTable.selectByIndex(row, scrollBehavior: 'auto');
        spinner.remove();
        return row;
      }

      row++;
    }

    spinner.remove();

    framework.toast(
      'Unable to find instance for field $fieldName [$hashCode]',
      title: 'Error',
    );

    return -1;
  }

  void _resetHistory() {
    history.hidden(true);
    history.clear();
    memoryPath = NavigationPath();
  }

  /// Finish callback from search class selected (auto-complete).
  void _callbackPopupSelectClass([bool cancel]) {
    if (cancel) {
      heapAutoCompletePopup.matcher.reset();
      heapPopupList.reset();
    } else {
      // Reset memory history selecting a class.
      _resetHistory();

      // Highlighted class is the class to select.
      final String selectedClass = heapPopupList.highlightedItem;
      if (selectedClass != null) _selectClass(selectedClass);
    }

    // Done with the popup.
    heapAutoCompletePopup.hide();
  }

  void _selectInstanceByObjectRef(String objectRefToFind) {
    removeInstanceTableView();

    // There's an instances table up.
    final HtmlTable<Object> instanceTable = tableStack.last;
    final List<InboundsTreeNode> nodes = instanceTable.model.data;

    final foundNode = nodes.firstWhere(
      (node) => node.instance?.objectRef == objectRefToFind,
      orElse: () => null,
    );
    if (foundNode != null) {
      instanceTable.selectByIndex(
        nodes.indexOf(foundNode),
        scrollBehavior: 'auto',
      );
    }
  }

  Future<void> _selectInstanceByHashCode(int instanceHashCode) async {
    // There's an instances table up.
    final HtmlTable<Object> instanceTable = tableStack.last;
    final List<InstanceSummary> instances = instanceTable.model.data;
    int row = 0;
    for (InstanceSummary instance in instances) {
      // Check each instance looking to find a particular object.
      // TODO(terry): Is there something faster for objectRef identity check?
      final eval = await evaluate(instance.objectRef, 'hashCode');
      final int evalHashCode = int.parse(eval?.valueAsString);

      if (evalHashCode == instanceHashCode) {
        // Found the object select the instance.
        instanceTable.selectByIndex(row, scrollBehavior: 'auto');
        return;
      }

      row++;
    }

    framework.toast('Unable to find instance [$instanceHashCode]',
        title: 'Error');
  }

  bool get _isClassSelectedAndInstancesReady =>
      tableStack.first.model.hasSelection &&
      tableStack.length == 2 &&
      tableStack.last.model.data.isNotEmpty;

  void selectClassInstance(String className, int instanceHashCode) {
    // Remove selection in class list.
    tableStack.first.clearSelection();
    // TODO(terry): Better solution is to await a Table event that tells us.
    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      if (!tableStack.first.model.hasSelection) {
        // Wait until the class list has no selection.
        timer.cancel();
      }
    });

    // Select the class (don't record this select in memory history). The
    // memoryPath will be added by NavigationState.inboundSelect - see below.
    _selectClass(className, record: false);

    // TODO(terry): Better solution is to await a Table event that tells us.
    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) async {
      // Wait until the class has been selected, 2 lists (class and instances
      // for the class exist) and the instances list has data.
      if (_isClassSelectedAndInstancesReady) {
        timer.cancel();

        await _selectInstanceByHashCode(instanceHashCode);
      }
    });
  }

  void selectClassAndInstanceInField(
    String className,
    String field,
    int instanceHashCode,
  ) async {
    fromMemoryHover = true;

    // Remove selection in class list.
    tableStack.first.clearSelection();
    // TODO(terry): Better solution is to await a Table event that tells us.
    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      if (!tableStack.first.model.hasSelection) {
        // Wait until the class list has no selection.
        timer.cancel();
      }
    });

    // Select the class (don't record this select in memory history). The
    // memoryPath will be added by NavigationState.inboundSelect - see below.
    _selectClass(className, record: false);

    // TODO(terry): Better solution is to await a Table event that tells us.
    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) async {
      // Wait until the class has been selected, 2 lists (class and instances
      // for the class exist) and the instances list has data.
      if (_isClassSelectedAndInstancesReady) {
        timer.cancel();

        final int rowToSelect =
            await _selectInstanceInFieldHashCode(field, instanceHashCode);
        if (rowToSelect != -1) {
          // Found the instance that refs the object (hashCode passed). Mark the
          // field name (fieldReference).  When the next instance memory path is
          // added (in select) the field ill be stored in the NavigationState.
          memoryPath.fieldReference = field;
        }

        // Wait for instance table, element 1, to have registered the selection.
        // TODO(terry): Better solution is to await a Table event that tells us.
        Timer.periodic(const Duration(milliseconds: 100), (Timer timer) async {
          if (tableStack.length == 2 &&
              tableStack.elementAt(1).model.hasSelection) {
            timer.cancel();

            // Done simulating all user UI actions as we navigate via hover thru
            // classes, instances and fields.
            fromMemoryHover = false;
          }
        });
      }
    });
  }

  void _pushNextTable(
    HtmlTable<dynamic> current,
    HtmlTable<dynamic> next, [
    HtmlInboundsTree inboundTree,
  ]) {
    // Remove any tables to the right of current from the DOM and the stack.
    while (tableStack.length > 1 && tableStack.last != current) {
      // TODO(terry): Hacky need to manage tables better.
      if (tableStack.length == 2) {
        _inboundTree = null;
      }
      tableStack.removeLast()
        ..element.element.remove()
        ..dispose();
    }

    // Push the new table on to the stack and to the right of current.
    if (next != null) {
      final bool isFirst = tableStack.isEmpty;
      tableStack.addLast(next);
      tableContainer.add(next.element);

      // TODO(terry): Hacky need to manage tables better.
      if (inboundTree != null) _inboundTree = inboundTree;

      if (!isFirst) {
        next.element.clazz('margin-left');
      }

      tableContainer.element.scrollTo(<String, dynamic>{
        'left': tableContainer.element.scrollWidth,
        'top': 0,
        'behavior': 'smooth',
      });
    }
  }

  Future<void> _resetAllocatorCounts() async {
    ga.select(ga.memory, ga.reset);

    memoryChart.plotReset();

    resetAccumulatorsButton.disabled = true;
    tableStack.first.element.display = null;
    final HtmlSpinner spinner =
        tableStack.first.element.add(HtmlSpinner.centered());

    try {
      originalHeapStats = await memoryController.resetAllocationProfile();

      removeAllButClassesTableView();

      _displayClassesSnapshot(
        classPattern: memoryController.settings.pattern,
        hidePrivates: memoryController.settings.hidePrivateClasses,
      );

      spinner.remove();
    } catch (e) {
      framework.toast('Reset failed ${e.toString()}', title: 'Error');
    } finally {
      resetAccumulatorsButton.disabled = false;
    }
  }

  final List<String> _knownSnapshotClasses = [];

  List<String> getKnownSnapshotClasses() {
    if (_knownSnapshotClasses.isEmpty) {
      final List<ClassHeapDetailStats> classesData =
          tableStack.first.model.data;
      for (ClassHeapDetailStats stat in classesData) {
        _knownSnapshotClasses.add(stat.classRef.name);
      }
    }

    return _knownSnapshotClasses;
  }

  Future<void> _search() async {
    ga.select(ga.memory, ga.search);

    // Subsequent snapshots will reset heapPopupList to empty.
    if (heapPopupList.isEmpty) {
      // Only fetch once between snapshots.
      heapPopupList.setList(getKnownSnapshotClasses());
    }

    if (!vmSearchField.isVisible) {
      vmSearchField.element.style.visibility = 'visible';
      vmSearchField.element.focus();
      heapAutoCompletePopup.show();
    } else {
      heapAutoCompletePopup.matcher.finish(); // Cancel popup auto-complete
    }
  }

  Future<void> _loadAllocationProfile() async {
    ga.select(ga.memory, ga.snapshot);

    memoryChart.plotSnapshot();

    // Empty the popup list - we'll repopulated from new snapshot.
    heapPopupList.setList([]);

    vmMemorySnapshotButton.disabled = true;

    tableStack.first.element.display = null;
    final HtmlSpinner spinner =
        tableStack.first.element.add(HtmlSpinner.centered());

    try {
      originalHeapStats = await memoryController.getAllocationProfile();

      spinner.remove();

      removeAllButClassesTableView();

      _displayClassesSnapshot(
        classPattern: memoryController.settings.pattern,
        hidePrivates: memoryController.settings.hidePrivateClasses,
      );
    } catch (e) {
      framework.toast('Snapshot failed ${e.toString()}', title: 'Error');
    } finally {
      vmMemorySnapshotButton.disabled = false;
      vmMemorySearchButton.disabled = false;
    }
  }

  static const String _wildcard = '*';

  /// Does the class name match a classPattern, where classPattern is:
  ///    ''        - matches everything.
  ///    '*'       - matches everything.
  ///    'NNN*'    - matches a class name starting with NNN.
  ///    '*NNN'    - matches a class name ending with NNN.
  ///    'NNN*MMM' - matches a class name starting with NNN and ending with MMM.
  ///    'NNN'     - matches a class name starting with NNN.
  ///
  bool _matchPattern(String classPattern, String className) {
    classPattern = classPattern.trim();
    if (classPattern.isEmpty) return true; // Matches everything.

    // If no _wildcard in the pattern then default to prefix matching.
    if (!classPattern.contains(_wildcard))
      return className.startsWith(classPattern);

    String pattern;
    if (classPattern.startsWith(_wildcard)) {
      pattern = classPattern.substring(1);
      return className.endsWith(pattern);
    } else if (classPattern.endsWith(_wildcard)) {
      pattern = classPattern.substring(0, classPattern.length - 1);
      return className.startsWith(pattern);
    }

    // Wildcard is in the middle of pattern. Match start pattern (left of
    // wildcard) and end pattern (right of wildcard).
    final index = classPattern.indexOf(_wildcard);
    assert(index > 0 && index < classPattern.length);

    final startMatch = classPattern.substring(0, index);
    final endMatch = classPattern.substring(index + 1);
    return className.startsWith(startMatch) && className.endsWith(endMatch);
  }

  /// Defaults to a classPattern of match everything and defaults to show class
  /// names that are private (begins with a underscore).
  void _displayClassesSnapshot({
    String classPattern = '',
    bool hidePrivates = false,
  }) {
    if (originalHeapStats == null) return;

    final HtmlSpinner spinner =
        tableStack.first.element.add(HtmlSpinner.centered());

    final List<ClassHeapDetailStats> heapStats = [];

    for (var heapEntry in originalHeapStats) {
      if (hidePrivates && heapEntry.classRef.name.startsWith('_')) continue;
      if (_matchPattern(classPattern, heapEntry.classRef.name)) {
        // Only display classes from libraries not being filtered.
        if (memoryController.libraryCollection
            .isDisplayClass(heapEntry.classRef.id)) {
          heapStats.add(heapEntry);
        }
      }
    }

    // Reset known snapshot classes, just changed.
    _knownSnapshotClasses.clear();

    tableStack.first.model.setRows(heapStats);

    _updateStatus(heapStats);
    spinner.remove();
  }

  Future<void> _gcNow() async {
    ga.select(ga.memory, ga.gC);

    gcNowButton.disabled = true;

    try {
      await memoryController.gc();
    } catch (e) {
      framework.toast('Unable to GC ${e.toString()}', title: 'Error');
    } finally {
      gcNowButton.disabled = false;
    }
  }

  void _updateListeningState() async {
    await serviceManager.onServiceAvailable;

    final bool shouldBeRunning = isCurrentScreen;

    if (shouldBeRunning && !memoryController.hasStarted) {
      await memoryController.startTimeline();

      pauseButton.disabled = false;
      resumeButton.disabled = true;

      vmMemorySnapshotButton.disabled = false;
      resetAccumulatorsButton.disabled = false;
      gcNowButton.disabled = false;

      memoryChart.disabled = false;
    }
  }

  /// VM Service has stopped (disconnected).
  void serviceDisconnect() {
    pauseButton.disabled = true;
    resumeButton.disabled = true;

    vmMemorySnapshotButton.disabled = true;
    resetAccumulatorsButton.disabled = true;
    settingsButton.disabled = true;
    gcNowButton.disabled = true;

    memoryChart.disabled = true;
  }

  void removeInstanceTableView() {
    if (tableContainer.element.children.length == 3) {
      tableContainer.element.children.removeLast();
    }
  }

  void removeAllButClassesTableView() {
    while (tableContainer.element.children.length > 1) {
      tableContainer.element.children.removeLast();
    }
  }

  HtmlTable<ClassHeapDetailStats> _createHeapStatsTableView() {
    final table = HtmlTable<ClassHeapDetailStats>.virtual()
      ..element.display = 'none'
      ..element.clazz('memory-table');

    table.model
      ..addColumn(MemoryColumnSize())
      ..addColumn(MemoryColumnInstanceCount())
      ..addColumn(MemoryColumnInstanceAccumulatedCount())
      ..addColumn(MemoryColumnClassName());

    table.model.sortColumn = table.model.columns.first;

    table.model.onSelect.listen((ClassHeapDetailStats row) async {
      ga.select(ga.memory, ga.inspectClass);
      // User selected a new class from the list of classes so the instance view
      // which would be the third child needs to be removed.
      removeInstanceTableView();

      final HtmlInboundsTree inboundTree =
          row == null ? null : await displayInboundReferences(row);
      if (inboundTree != null) {
        final HtmlTreeTable<InboundsTreeNode> tree =
            inboundTree.referencesTable;
        _pushNextTable(table, tree, inboundTree);
      }
    });

    return table;
  }

  Future<HtmlInboundsTree> displayInboundReferences(
      ClassHeapDetailStats row) async {
    final treeData = InboundsTreeData()..data = InboundsTreeNode.root();

    final List<InstanceSummary> instanceRows =
        await memoryController.getInstances(
      row.classRef.id,
      row.classRef.name,
      row.instancesCurrent,
    );

    for (var instance in instanceRows) {
      final instanceNode = InboundsTreeNode.instance(instance);
      treeData.data.addChild(instanceNode);
      // Place holder to lazily compute next child when parent node is expanded.
      // Place holder to lazily compute next child when parent node is expanded.
      instanceNode.addChild(InboundsTreeNode.empty());
    }

    final inboundsTreeTable =
        HtmlInboundsTree(this, treeData, row.classRef.name);
    return inboundsTreeTable..update();
  }

  Future<String> computeInboundReference(
    String objectRef,
    InboundsTreeNode instanceNode,
  ) async {
    final refs = await getInboundReferences(objectRef, 1000);

    String instanceHashCode;
    if (isMemoryExperiment) {
      // TODO(terry): Expensive need better VMService identity for objectRef.
      // Get hashCode identity object id changes but hashCode is our identity.
      final hashCodeResult = await evaluate(objectRef, 'hashCode');
      instanceHashCode = hashCodeResult?.valueAsString;
    }

    final List<ClassHeapDetailStats> allClasses = tableStack.first.model.data;

    computeInboundRefs(allClasses, refs, (
      String referenceName,
      String owningAllocator,
      bool owningAllocatorIsAbstract,
    ) async {
      if (!owningAllocatorIsAbstract && owningAllocator.isNotEmpty) {
        final inboundNode =
            InboundsTreeNode(owningAllocator, referenceName, instanceHashCode);
        instanceNode.addChild(inboundNode);
        if (isMemoryExperiment) inboundNode.addChild(InboundsTreeNode.empty());
      }
    });

    return instanceHashCode;
  }

  Future<InstanceSummary> findLostObjectRef(
    String classRef,
    int instanceHashCode,
  ) async {
    final classDetails = findClassDetails(classRef);
    if (classDetails != null) {
      final List<InstanceSummary> instances =
          await memoryController.getInstances(
        classDetails.classRef.id,
        classDetails.classRef.name,
        classDetails.instancesCurrent,
      );
      for (var instance in instances) {
        final InstanceRef eval = await evaluate(instance.objectRef, 'hashCode');
        final int evalResult = int.parse(eval?.valueAsString);
        if (evalResult == instanceHashCode) {
          // Found the instance.
          return instance;
        }
      }
    }

    return null;
  }

  Future<Instance> getInstance(String objectRef) async {
    Instance instance;
    try {
      final dynamic theObject = await memoryController.getObject(objectRef);
      if (theObject is Instance) {
        instance = theObject;
      } else if (theObject is Sentinel) {
        instance = null;
        // TODO(terry): Tracking Sentinel's to be removed.
        framework.toast('Sentinel $objectRef', title: 'Warning');
      }
    } catch (e) {
      // Log this problem not sure how it can really happen.
      ga.error('Memory select (getInstance): $e', false);

      instance = null; // Signal a problem
    }

    return instance;
  }

  void updateInstancesTree() {
    _inboundTree.update();
  }

  void select(InboundsTreeNode rowNode) async {
    ga.select(ga.memory, ga.inspectInstance);

    // User selected a new instance from the list of class instances so the
    // instance view which would be the third child needs to be removed.
    removeInstanceTableView();

    if (rowNode?.instance == null) return;

    Instance instance = await getInstance(rowNode.instance.objectRef);
    if (instance == null) {
      // TODO(terry): Eliminate for eval
      // Eval objectRef ids have changed re-fetch objectRef ids.
      final newInstance = await findLostObjectRef(
        rowNode.instance.classRef,
        int.parse(rowNode.instanceHashCode),
      );

      framework.toast(
        'Re-computed ${rowNode.instance.objectRef} -> ${newInstance.objectRef}',
        title: 'Message',
      );

      // Update to the new objectRef id.
      rowNode.setInstance(newInstance, rowNode.instanceHashCode, true);

      instance = await getInstance(rowNode.instance.objectRef);

      _inboundTree.update();

      // Re-computing could cause instance in TableTree to move (change row).
      // Find it and select it again.
      _selectInstanceByObjectRef(rowNode.instance.objectRef);
    }

    tableContainer.add(_createInstanceView(
      instance != null
          ? rowNode.instance.objectRef
          : 'Unable to fetch instance ${rowNode.name}',
      rowNode.instance.className,
    ));

    tableContainer.element.scrollTo(<String, dynamic>{
      'left': tableContainer.element.scrollWidth,
      'top': 0,
      'behavior': 'smooth',
    });

    // Allow inspection of the memory object.
    memoryDataView.showFields(instance != null ? instance.fields : []);
  }

  /// TD element used to simulate hover state when hover card is visible. When
  /// not null the mouse is actively in the hover card.
  CoreElement _tdCellHover;

  /// InstanceSummary of the visible hover card.
  HtmlHoverCell<InstanceSummary> _currentHoverSummary;

  /// This is the listener for the hover card (hoverPopup's) onMouseOver, it's
  /// designed to keep the hover state (background-color for the TD same as the
  /// CSS :hover) as the mouse slides to the hover card. It gives the appearance
  /// that hover is still active in the TD.
  void _mouseInHover(html.MouseEvent evt) {
    final CoreElement cell = _currentHoverSummary?.cell;

    if (cell != null) _tdCellHover = cell;

    // Simulate the :hover when the mouse in hover card.
    _tdCellHover?.clazz('allocation-hover', removeOthers: true);
    _tdCellHover?.clazz('left');
  }

  /// This is the listener for the hover card (hoverPopup's) onMouseLeave, it's
  /// designed to end the hover state (background-color for the TD same as the
  /// CSS :hover) as the mouse slides out of the hover card.  It gives the
  /// appearance that the hover is not active.
  void _mouseOutHover(html.MouseEvent evt) {
    // Done simulating hover, hover card is closing.  Reset to CSS handling the
    // :hover for the allocation class.
    _tdCellHover?.clazz('allocation', removeOthers: true);
    _tdCellHover?.clazz('left');

    if (_tdCellHover != null) _tdCellHover = null;

    _currentHoverSummary = null;

    // We're really leaving hover so close it.
    hoverPopup.clear(); // Remove all children.
    hoverPopup.display = 'none';
  }

  void _closeHover(HtmlHoverCell<InstanceSummary> newCurrent) {
    // We're really leaving hover so close it.
    hoverPopup.clear(); // Remove all children.
    hoverPopup.display = 'none';

    _currentHoverSummary = newCurrent;
  }

  void _maybeCloseHover() {
    final String hoverToClose = _currentHoverSummary?.data?.objectRef;
    Timer(const Duration(milliseconds: 50), () {
      if (_tdCellHover == null &&
          hoverToClose == _currentHoverSummary?.data?.objectRef) {
        // We're really leaving hover so close it.
        _closeHover(null);
      }
    });
  }

  static const String dataHashCode = 'data-hashcode';
  static const String dataOwningClass = 'data-owning-class';
  static const String dataRef = 'data-ref';

  void hoverInstanceAllocations(HoverCellData<InstanceSummary> data) async {
    final HtmlHoverCell<InstanceSummary> hover = data;
    if (hover.cell == null) {
      // Hover out of the cell.
      _maybeCloseHover();
      return;
    }

    // Hover in the cell.
    if (hover.data != _currentHoverSummary?.data) {
      // Selecting a different instance then what's current.
      _closeHover(hover);
    }

    // Entering Hover again?
    if (hoverPopup.element.children.isNotEmpty) return;

    final CoreElement ulElem = ul();
    final refs = await getInboundReferences(hover.data.objectRef, 1000);

    if (refs == null) {
      framework.toast(
        'Instance ${hover.data.objectRef} - Sentinel/Expired.',
      );
      return;
    }

    ulElem.add(li(c: 'allocation-li-title')
      ..add([
        span(text: 'Allocated', c: 'allocated-by-class-title'),
        span(text: 'Referenced', c: 'ref-by-title')
      ]));

    final List<ClassHeapDetailStats> allClasses = tableStack.first.model.data;

    computeInboundRefs(
      allClasses,
      refs,
      (
        String referenceName,
        String owningAllocator,
        bool owningAllocatorIsAbstract,
      ) async {
        // Callback function to build each item in the hover card.
        final classAllocation = owningAllocatorIsAbstract
            ? 'allocation-abstract allocated-by-class'
            : 'allocated-by-class';

        final fieldAllocation =
            owningAllocatorIsAbstract ? 'allocation-abstract ref-by' : 'ref-by';

        final CoreElement liElem = li(c: 'allocation-li')
          ..add([
            span(
              text: 'class $owningAllocator',
              c: classAllocation,
            ),
            span(
              text: 'field $referenceName',
              c: fieldAllocation,
            ),
          ]);
        if (owningAllocatorIsAbstract) {
          // Mark as grayed/italic
          liElem.clazz('li-allocation-abstract');
        }
        if (!owningAllocatorIsAbstract && owningAllocator.isNotEmpty) {
          // TODO(terry): Expensive need better VMService identity for objectRef.
          // Get hashCode identity object id changes but hashCode is our identity.
          final hashCodeResult =
              await evaluate(hover.data.objectRef, 'hashCode');

          liElem.setAttribute(dataHashCode, hashCodeResult?.valueAsString);
          liElem.setAttribute(dataOwningClass, owningAllocator);
          liElem.setAttribute(dataRef, referenceName);
        }
        liElem.onClick.listen((evt) {
          final html.Element e = evt.currentTarget;

          String className = e.getAttribute(dataOwningClass);
          if (className == null || className.isEmpty) {
            className = e.parent.getAttribute(dataOwningClass);
          }
          String refName = e.getAttribute(dataRef);
          if (refName == null || refName.isEmpty) {
            refName = e.parent.getAttribute(dataRef);
          }
          String objectHashCode = e.getAttribute(dataHashCode);
          if (objectHashCode == null || objectHashCode.isEmpty) {
            objectHashCode = e.parent.getAttribute(dataHashCode);
          }
          final int instanceHashCode = int.parse(objectHashCode);

          // Done with the hover - close it down.
          _closeHover(null);

          // Make sure its a known class (not abstract).
          if (className.isNotEmpty &&
              refName.isNotEmpty &&
              instanceHashCode != null) {
            // Display just the instances of classes with ref
            selectClassAndInstanceInField(className, refName, instanceHashCode);
          }
        });
        ulElem.add(liElem);
      },
    );

    if (hover.cell != null && hover.cell.hasClass('allocation')) {
      // Hover over
      final int top = hover.cell.top + 10;
      final int left = hover.cell.left + 21;

      hoverPopup.clear(); // TODO(terry): Workaround multiple ULs?

      hoverPopup.add(ulElem);

      // Display the popup.
      hoverPopup
        ..display = 'block'
        ..element.style.top = '${top}px'
        ..element.style.left = '${left}px'
        ..element.style.height = '';
    }
  }

  CoreElement _createInstanceView(String objectRef, String className) {
    final MemoryDescriber describer = (BoundField field) async {
      if (field == null) {
        return null;
      }

      final dynamic value = field.value;

      // TODO(terry): Replace two if's with switch (value.runtimeType)
      if (value is Sentinel) {
        return value.valueAsString;
      }

      if (value is TypeArgumentsRef) {
        return value.name;
      }

      final InstanceRef ref = value;

      if (ref?.valueAsString != null && !ref.valueAsStringIsTruncated) {
        return ref.valueAsString;
      } else {
        // Shouldn't happen but want to check - log to analytics.
        ga.error(
            'Memory _createInstanceView: UNKNOWN BoundField $objectRef', false);
      }

      return null;
    };

    memoryDataView = HtmlMemoryDataView(memoryController, describer);

    return div(
        c: 'table-border table-virtual memory-table margin-left debugger-menu')
      ..layoutVertical()
      ..add(<CoreElement>[
        div(
          text: '$className instance $objectRef',
          c: 'memory-inspector',
        ),
        memoryDataView.element,
      ]);
  }

  void _updateStatus(List<ClassHeapDetailStats> data) {
    if (data == null) {
      classCountStatus.element.text = '';
      objectCountStatus.element.text = '';
    } else {
      classCountStatus.element.text = '${nf.format(data.length)} classes';
      int objectCount = 0;
      for (ClassHeapDetailStats stats in data) {
        objectCount += stats.instancesCurrent;
      }
      objectCountStatus.element.text = '${nf.format(objectCount)} objects';
    }
    experimentStatus.element.text =
        isMemoryExperiment ? 'Experiment' : 'Memory';
  }
}

/// Path consists of:
///    Class selected (from Class list):
///      _className
///      _hashCode = empty
///      field = empty
///
///   Instance selected (from Instance list):
///      _className
///      _hashCode [hashCode of instance]
///      field = empty
///
///   Hover (from inboundReferences) parent allocations:
///      _className [class name of parent class that allocated object]
///      _hashCode [hashCode of instance]
///      field [field of parent class that has ref]
class NavigationState {
  NavigationState.classSelect(this._className);

  NavigationState.instanceSelect(this._className, this._hashCode);

  // data attribute names.
  static const String dataIndex = 'data-index';
  static const String dataClass = 'data-class';
  static const String dataField = 'data-field';
  static const String dataHashCode = 'data-hashcode';

  String field = '';

  String get className => _className;
  final String _className;

  int get instanceHashCode => _hashCode;
  int _hashCode;

  bool get isClass =>
      _className.isNotEmpty && field.isEmpty && _hashCode == null;

  bool get isInstance =>
      _className.isNotEmpty && field.isEmpty && _hashCode != null;

  bool get isInbound =>
      _className.isNotEmpty && field.isNotEmpty && _hashCode != null;

  // Create a span with all information to navigate through the class list and
  // instance list. The span element will look like:
  //
  //    <span class=N data-index=# data-class=N data-field=N data-hashcode=N>
  //      class[.field]
  //    </span>
  //
  // where:
  //    class=N is the css class for styling
  //    index=# is the index of this Navigation link in the NavigationPath list
  //    data-class=N is the class selected in the memory class list
  //    data-field=N if specified, references previous history hashcode (object)
  //    data-hashcode=N if specified, object referenced in this data-class field
  CoreElement link(int index, [bool last = false]) {
    final String spanText = field.isNotEmpty
        ? '$className.$field'
        : isInstance ? '$className (instance)' : className;

    final CoreElement spanElem =
        span(text: spanText, c: last ? 'history-link-last' : 'history-link');

    spanElem.setAttribute(dataIndex, '$index');
    spanElem.setAttribute(dataClass, className);
    if (field.isNotEmpty) spanElem.setAttribute(dataField, field);
    if (instanceHashCode != null) {
      spanElem.setAttribute(dataHashCode, instanceHashCode.toString());
    }

    return spanElem;
  }

  CoreElement get separator => span(text: '>', c: 'history-separator');
}

// Used to manage all memory navigation from user clicks or hover card
// navigation so user can visually understand the relationship of the current
// memory object being displayed.
class NavigationPath {
  final List<NavigationState> _path = [];

  // Global field name next add if state object isInstance then store the field
  // name in the state.
  String _inboundFieldName = '';

  set fieldReference(String field) => _inboundFieldName = field;

  bool get isEmpty => _path.isEmpty;

  bool get isNotEmpty => _path.isNotEmpty;

  void add(NavigationState state) {
    if (state.isInbound) {
      throw Exception('Inbound use not valid here.');
    }

    // If adding a state and the global inbound is set, then record this field
    // with the state.
    if (state.isInstance && _inboundFieldName.isNotEmpty) {
      state.field = _inboundFieldName;
    }

    _inboundFieldName = '';

    if (_path.isNotEmpty) {
      final lastState = _path.last;
      // if last state in path and same state we're to push, ignore - class
      // being set by a click in history navigation.
      if (lastState.isClass &&
          state.isClass &&
          lastState.className == state.className) return;
    }

    _path.add(state);
  }

  NavigationState get(int index) => _path[index];

  void remove(NavigationState stateToRemove) {
    for (int row = 0; row < _path.length; row++) {
      final NavigationState state = _path[row];
      if (stateToRemove == state) {
        assert(state.instanceHashCode == stateToRemove.instanceHashCode &&
            state.className == stateToRemove.className &&
            state.field == stateToRemove.field);
        _path.removeRange(row, _path.length);
        return;
      }
    }
  }

  /// Is the last item in the path an inBound NavigationState.
  bool get isLastInBound => _path.isNotEmpty ? _path.last.isInbound : false;

  bool get isLastInstance => _path.isNotEmpty ? _path.last.isInstance : false;

  // Display all the NavigationStates in our _path as UI links.
  void displayPathsAsLinks(
    CoreElement parent, {
    void Function(CoreElement) clickHandler,
  }) {
    for (int index = 0; index < _path.length; index++) {
      final NavigationState state = _path[index];
      final bool lastLink = _path.length - 1 == index; // Last item in path?
      final CoreElement link = state.link(index, lastLink);
      if (clickHandler != null) {
        link.click(() {
          final CoreElement element = link;
          clickHandler(element);
        });
      }
      parent.add(link);
      if (!lastLink) parent.add(state.separator);
    }
  }
}
