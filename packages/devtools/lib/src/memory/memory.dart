// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:html' as html;

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../popup.dart';
import '../tables.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/ui_utils.dart';
import '../utils.dart';
import 'memory_chart.dart';
import 'memory_controller.dart';
import 'memory_data_view.dart';
import 'memory_detail.dart';
import 'memory_protocol.dart';
import 'memory_service.dart';

const memoryScreenId = 'memory';

class MemoryScreen extends Screen with SetStateMixin {
  MemoryScreen({bool disabled, String disabledTooltip})
      : super(
          name: 'Memory',
          id: memoryScreenId,
          iconClass: 'octicon-package',
          disabled: disabled,
          disabledTooltip: disabledTooltip,
        ) {
    classCountStatus = StatusItem();
    addStatusItem(classCountStatus);

    objectCountStatus = StatusItem();
    addStatusItem(objectCountStatus);
  }

  final MemoryController memoryController = MemoryController();

  StatusItem classCountStatus;

  StatusItem objectCountStatus;

  PButton pauseButton;

  PButton resumeButton;

  // The autocomplete view manages the textfield and popup list.
  CoreElement vmSearchField;
  PopupListView<String> heapPopupList;
  PopupAutoCompleteView heapPopup;

  PButton vmMemorySearchButton;
  PButton vmMemorySnapshotButton;

  PButton resetAccumulatorsButton;

  PButton filterLibrariesButton;

  PButton gcNowButton;

  ListQueue<Table<Object>> tableStack = ListQueue<Table<Object>>();

  MemoryChart memoryChart;

  CoreElement tableContainer;
  CoreElement history; // Memory navigation history.

  NavigationPath memoryPath = NavigationPath();
  bool fromMemoryHover = false;

  MemoryDataView memoryDataView;

  MemoryTracker memoryTracker;

  ProgressElement progressElement;

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
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    html.window.onKeyDown.listen((html.KeyboardEvent e) {
      if (e.ctrlKey) {
        switch (e.key) {
          case 'f': // CTRL + f
            _search();
            e.preventDefault();
            break;
        }
      }
    });

    resumeButton = PButton.icon('Resume', FlutterIcons.resume_white_disabled_2x)
      ..primary()
      ..small()
      ..disabled = true;

    pauseButton = PButton.icon('Pause', FlutterIcons.pause_black_2x)..small();

    heapPopupList = PopupListView<String>();

    vmSearchField = CoreElement('input', classes: 'search-text')
      ..setAttribute('type', 'text')
      ..setAttribute('placeholder', 'filter')
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
      ..click(_loadAllocationProfile)
      ..disabled = true;
    resetAccumulatorsButton = PButton.icon(
        'Reset', FlutterIcons.resetAccumulators,
        title: 'Reset Accumulators')
      ..small()
      ..click(_resetAllocatorCounts)
      ..disabled = true;
    filterLibrariesButton =
        PButton.icon('Filter', FlutterIcons.filter, title: 'Filter')
          ..small()
          ..disabled = true;
    heapPopup = PopupAutoCompleteView(
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

    history = div(c: 'history-navigation-hidden');

    screenDiv.add(<CoreElement>[
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..layoutHorizontal()
            ..clazz('align-items-center')
            ..add(<CoreElement>[
              div(c: 'btn-group flex-no-wrap')
                ..add(<CoreElement>[
                  pauseButton,
                  resumeButton,
                ]),
              div()..flex(),
              div(c: 'btn-group collapsible-700 flex-no-wrap margin-left')
                ..add(<CoreElement>[
                  vmSearchField,
                  vmMemorySearchButton,
                  vmMemorySnapshotButton,
                  resetAccumulatorsButton,
                  filterLibrariesButton,
                  gcNowButton,
                ]),
            ]),
        ]),
      heapPopup, // Auto-complete popup
      memoryChart = MemoryChart(memoryController)..disabled = true,
      tableContainer = div(c: 'section overflow-auto')
        ..layoutHorizontal()
        ..flex(),
      history,
    ]);

    memoryController.onDisconnect.listen((__) {
      serviceDisconnet();
    });

    maybeAddDebugMessage(framework, memoryScreenId);

    _pushNextTable(null, _createHeapStatsTableView());

    _updateStatus(null);

    return screenDiv;
  }

  ClassHeapDetailStats _searchClass(String className) {
    final List<ClassHeapDetailStats> classesData = tableStack.first.data;
    for (ClassHeapDetailStats stat in classesData) {
      if (stat.classRef.name == className) {
        return stat;
      }
    }

    return null;
  }

  void _selectClass(String className, [record = true]) {
    final List<ClassHeapDetailStats> classesData = tableStack.first.data;
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

  // Show the spinner we're computing...
  Spinner createSpinner(Table<Object> table) {
//    final html.Rectangle r = table.element.element.getBoundingClientRect();
//    final int topPosition = r.top + (r.height / 2).round();
//    final int leftPosition = r.left + (r.width / 2).round();

    final Spinner spinner = Spinner.centered();
//TODO(terry): Cleanup
    //final Spinner spinner = Spinner()..clazz('padded');
/*
    spinner.element.style
      ..position = 'absolute'
      ..top = '${topPosition}px'
      ..left = '${leftPosition}px'
      ..zIndex = '1000';
*/
    return spinner;
  }

  Future<int> _selectInstanceInFieldHashCode(
      String field, String hashCode) async {
    final Table<Object> instanceTable = tableStack.elementAt(1);
    final Spinner spinner = createSpinner(instanceTable);
    instanceTable.element.add(spinner);

    // There's an instances table up.
    final List<InstanceSummary> instances = instanceTable.data;
    int row = 0;
    for (InstanceSummary instance in instances) {
      // Check the field in each instance looking to find the object being held
      // (the hashCode passed in matches the particular field's hashCode)
      final evalResult = await evaluate(instance.objectRef, '$field.hashCode');
      if (evalResult != null && evalResult.valueAsString == hashCode) {
        // Found the object select the instance.
        instanceTable.selectByIndex(row, scrollBehavior: 'auto');
        spinner.element.remove();
        return row;
      }
      row++;
    }

    spinner.element.remove();

    framework.toast('Unable to find instance for field $field [$hashCode]',
        title: 'Error');

    return -1;
  }

  void _resetHistory() {
    history..clazz('history-navigation-hidden', removeOthers: true);
    history.clear();
    memoryPath = NavigationPath();
  }

  /// Finish callback from search class selected (auto-complete).
  void _callbackPopupSelectClass([bool cancel]) {
    if (cancel) {
      heapPopup.matcher.reset();
      heapPopupList.reset();
    } else {
      // Reset memory history selecting a class.
      _resetHistory();

      // Highlighted class is the class to select.
      final String classSelected = heapPopupList.highlightedItem;
      _selectClass(classSelected);
    }

    // Done with the popup.
    heapPopup.hide();
  }

  Future<void> _selectInstanceByHashCode(String objectHashCode) async {
    // There's an instances table up.
    final Table<Object> instanceTable = tableStack.last;
    final List<InstanceSummary> instances = instanceTable.data;
    int row = 0;
    for (InstanceSummary instance in instances) {
      // Check each instance looking to find a particular object.
      final evalResult = await evaluate(instance.objectRef, 'hashCode');
      if (evalResult != null && evalResult.valueAsString == objectHashCode) {
        // Found the object select the instance.
        instanceTable.selectByIndex(row, scrollBehavior: 'auto');
        return;
      }
      row++;
    }

    framework.toast('Unable to find instance [$objectHashCode]',
        title: 'Error');
  }

  void selectClassInstance(String className, String objectHashCode) {
    // Remove selection in class list.
    tableStack.first.clearSelection();
    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      if (!tableStack.first.hasSelection) {
        // Wait until the class list has no selection.
        timer.cancel();
      }
    });

    // Select the class (don't record this select in memory history). The
    // memoryPath will be added by NavigationState.inboundSelect - see below.
    _selectClass(className, false);

    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) async {
      // Wait until the class has been selected, 2 lists (class and instances
      // for the class exist) and the instances list has data.
      if (tableStack.first.hasSelection &&
          tableStack.length == 2 &&
          tableStack.last.data.isNotEmpty) {
        timer.cancel();

        await _selectInstanceByHashCode(objectHashCode);
      }
    });
  }

  void selectClassAndInstanceInField(
    String className,
    String field,
    String hashCode,
  ) async {
    fromMemoryHover = true;

    // Remove selection in class list.
    tableStack.first.clearSelection();
    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      if (!tableStack.first.hasSelection) {
        // Wait until the class list has no selection.
        timer.cancel();
      }
    });

    // Select the class (don't record this select in memory history). The
    // memoryPath will be added by NavigationState.inboundSelect - see below.
    _selectClass(className, false);

    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) async {
      // Wait until the class has been selected, 2 lists (class and instances
      // for the class exist) and the instances list has data.
      if (tableStack.first.hasSelection &&
          tableStack.length == 2 &&
          tableStack.last.data.isNotEmpty) {
        timer.cancel();

        final int rowToSelect =
            await _selectInstanceInFieldHashCode(field, hashCode);
        if (rowToSelect != -1) {
          // Found the instance that refs the object (hashCode passed). Mark the
          // field name (fieldReference).  When the next instance memory path is
          // added (in select) the field ill be stored in the NavigationState.
          memoryPath.fieldReference = field;
        }

        // Wait for instance table, element 1, to have registered the selection.
        Timer.periodic(const Duration(milliseconds: 100), (Timer timer) async {
          if (tableStack.length == 2 && tableStack.elementAt(1).hasSelection) {
            timer.cancel();

            // Done simulating all user UI actions as we navigate via hover thru
            // classes, instances and fields.
            fromMemoryHover = false;
          }
        });
      }
    });
  }

  void _pushNextTable(Table<dynamic> current, Table<dynamic> next) {
    // Remove any tables to the right of current from the DOM and the stack.
    while (tableStack.length > 1 && tableStack.last != current) {
      tableStack.removeLast()
        ..element.element.remove()
        ..dispose();
    }

    // Push the new table on to the stack and to the right of current.
    if (next != null) {
      final bool isFirst = tableStack.isEmpty;

      tableStack.addLast(next);
      tableContainer.add(next.element);

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
    final Spinner spinner = tableStack.first.element.add(Spinner.centered());

    try {
      final List<ClassHeapDetailStats> heapStats =
          await memoryController.resetAllocationProfile();
      tableStack.first.setRows(heapStats);
      _updateStatus(heapStats);
      spinner.remove();
    } catch (e) {
      framework.toast('Reset failed ${e.toString()}', title: 'Error');
    } finally {
      resetAccumulatorsButton.disabled = false;
    }
  }

  List<String> _knownSnapshotClasses = [];
  List<String> getAllClassesKnown() {
    if (_knownSnapshotClasses.isEmpty) {
      final List<ClassHeapDetailStats> classesData = tableStack.first.data;
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
      heapPopupList.setList(getAllClassesKnown());
    }

    if (vmSearchField.element.style.visibility != 'visible') {
      vmSearchField.element.style.visibility = 'visible';
      vmSearchField.element.focus();
      heapPopup.show();
    } else {
      heapPopup.matcher.finish(false); // Cancel the popup auto-complete.
    }
  }

  Future<void> _loadAllocationProfile({bool reset = false}) async {
    ga.select(ga.memory, ga.snapshot);

    memoryChart.plotSnapshot();

    // Empty the popup list - we'll repopulated from new snapshot.
    heapPopupList.setList([]);

    vmMemorySnapshotButton.disabled = true;
    tableStack.first.element.display = null;
    final Spinner spinner = tableStack.first.element.add(Spinner.centered());

    try {
      final List<ClassHeapDetailStats> heapStats =
          await memoryController.getAllocationProfile();

      // Reset known snapshot classes, just changed.
      _knownSnapshotClasses = [];

      tableStack.first.setRows(heapStats);
      _updateStatus(heapStats);
      spinner.remove();
    } catch (e) {
      framework.toast('Snapshot failed ${e.toString()}', title: 'Error');
    } finally {
      vmMemorySnapshotButton.disabled = false;
      vmMemorySearchButton.disabled = false;
    }
  }

  Future<Null> _gcNow() async {
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
    await serviceManager.serviceAvailable.future;

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

  // VM Service has stopped (disconnected).
  void serviceDisconnet() {
    pauseButton.disabled = true;
    resumeButton.disabled = true;

    vmMemorySnapshotButton.disabled = true;
    resetAccumulatorsButton.disabled = true;
    filterLibrariesButton.disabled = true;
    gcNowButton.disabled = true;

    memoryChart.disabled = true;
  }

  void _removeInstanceView() {
    if (tableContainer.element.children.length == 3) {
      tableContainer.element.children.removeLast();
    }
  }

  Table<ClassHeapDetailStats> _createHeapStatsTableView() {
    final Table<ClassHeapDetailStats> table =
        Table<ClassHeapDetailStats>.virtual()
          ..element.display = 'none'
          ..element.clazz('memory-table');

    table.addColumn(MemoryColumnSize());
    table.addColumn(MemoryColumnInstanceCount());
    table.addColumn(MemoryColumnInstanceAccumulatedCount());
    table.addColumn(MemoryColumnClassName());

    table.sortColumn = table.columns.first;

    table.onSelect.listen((ClassHeapDetailStats row) async {
      ga.select(ga.memory, ga.inspectClass);
      // User selected a new class from the list of classes so the instance view
      // which would be the third child needs to be removed.
      _removeInstanceView();

      if (!fromMemoryHover) _resetHistory();

      final Table<InstanceSummary> newTable =
          row == null ? null : await _createInstanceListTableView(row);
      _pushNextTable(table, newTable);
    });

    return table;
  }

  // Popup used to show where allocation occurred and references to instance.
  final CoreElement instancePopup = div(c: 'allocation-popup');

  Future<Table<InstanceSummary>> _createInstanceListTableView(
      ClassHeapDetailStats row) async {
    final Table<InstanceSummary> table = new Table<InstanceSummary>.virtual()
      ..element.clazz('memory-table');

    try {
      final List<InstanceSummary> instanceRows =
          await memoryController.getInstances(
        row.classRef.id,
        row.classRef.name,
        row.instancesCurrent,
      );

      table.addColumn(new MemoryColumnSimple<InstanceSummary>(
        '${instanceRows.length} Instances of ${row.classRef.name}',
        (InstanceSummary row) => row.objectRef,
      ));

      table.addColumn(MemoryColumnSimple<InstanceSummary>(
          '', (InstanceSummary expand) => '<div class="alloc-image"> </div>',
          cssClass: 'allocation', usesHtml: true, hover: true));

      table.setRows(instanceRows);
    } catch (e) {
      framework.toast(
        'Problem fetching instances of ${row.classRef.name}: $e',
        title: 'Error',
      );
    }

    table.onCellHover.listen(hoverInstanceAllocations);
    table.onSelect.listen(select);

    return table;
  }

  void select(InstanceSummary row) async {
    ga.select(ga.memory, ga.inspectInstance);

    // User selected a new instance from the list of class instances so the
    // instance view which would be the third child needs to be removed.
    _removeInstanceView();

    Instance instance;
    try {
      instance = await memoryController.getObject(row.objectRef);

      final dynamic theObject = await memoryController.getObject(row.objectRef);
      if (theObject is Instance) {
        instance = theObject;
      } else if (theObject is Sentinel) {
        instance = null;
        // TODO(terry): Tracking Sentinel's to be removed.
        framework.toast('Sentinel ${row.objectRef}', title: 'Warning');
      }
    } catch (e) {
      instance = null; // Signal a problem
    } finally {
      tableContainer.add(_createInstanceView(
        instance != null
            ? row.objectRef
            : 'Unable to fetch instance ${row.objectRef}',
        row.className,
      ));

      tableContainer.element.scrollTo(<String, dynamic>{
        'left': tableContainer.element.scrollWidth,
        'top': 0,
        'behavior': 'smooth',
      });

      // Allow inspection of the memory object.
      memoryDataView.showFields(instance != null ? instance.fields : []);

      // Record this navigation.
      final InstanceRef hashCodeResult =
          await evaluate(row.objectRef, 'hashCode');

      if (!fromMemoryHover &&
          (memoryPath.isLastInBound || memoryPath.isLastInstance)) {
        // User clicked an instance, start new history with this instance.
        _resetHistory();
      }

      // Record the memory navigation.
      memoryPath.add(NavigationState.instanceSelect(
        row.className,
        hashCodeResult.valueAsString,
      ));

      if (memoryPath.isLastInBound) {
        // Re-construct memory navigation and display.
        history.clear();
        memoryPath.addPathsLinks(history, _handleHistoryClicks);

        history..clazz('history-navigation', removeOthers: true);
      }
    }
  }

  void _handleHistoryClicks(CoreElement element) {
    // Handle clicking in the history links.
    if (element.tag == 'SPAN' && element.hasClass('history-link')) {
      final attrs = element.attributes;

      final int dataIndex = int.parse(attrs[NavigationState.dataIndex]);

      final String dataClass = attrs[NavigationState.dataClass];
      final String dataField = attrs.containsKey(NavigationState.dataField)
          ? attrs[NavigationState.dataField]
          : '';
      final String dataHashCode =
          attrs.containsKey(NavigationState.dataHashCode)
              ? attrs[NavigationState.dataHashCode]
              : '';

      final NavigationState state = memoryPath.get(dataIndex);

      // The clicked link's attributes and real NavigationState should match.
      assert(dataClass == state.className &&
          dataField == state.field &&
          dataHashCode == state.objectHashCode);

      // Prune remove this state and to the end as well.
      memoryPath.remove(state);

      if (state.isClass) {
        _selectClass(state.className);
      } else if (state.isInstance) {
        selectClassInstance(state.className, state.objectHashCode);
      } else if (state.isInbound) {
        // Same as selecting the class instance but record the field, don't
        // need to match following the refs.
        memoryPath.fieldReference = state.field;
        selectClassInstance(state.className, state.objectHashCode);
      } else {
        assert(false, 'Unknown NavigationState');
      }

      history.clear();
      Timer(const Duration(milliseconds: 100), () {
        if (!memoryPath.isLastInBound) {
          history..clazz('history-navigation-hidden', removeOthers: true);
        } else {
          memoryPath.addPathsLinks(history, _handleHistoryClicks);
        }
      });
    }
  }

  void hoverInstanceAllocations(HoverCellData<InstanceSummary> hover) async {
    if (hover.cell == null) {
      // Hover out.
      instancePopup.clear(); // Remove all children.
      instancePopup.display = 'none';
      return;
    }

    // Entering Hover again?
    if (instancePopup.element.children.isNotEmpty) return;

    final CoreElement ulElem = ul();
    final InboundReferences refs =
        await getInboundReferences(hover.data.objectRef, 1000);
    ulElem.add(li(c: 'allocation-li-title')
      ..add([
        span(text: 'Allocated', c: 'allocated-by-class-title'),
        span(text: 'Referenced', c: 'ref-by-title')
      ]));

    for (InboundReference element in refs.elements) {
      // Could be a reference to an evaluate so this isn't known.

      // Looks like an object created from an evaluate, ignore it.
      if (element.parentField == null && element.json == null) continue;

      // TODO(terry): Verify looks like internal class (maybe to C code).
      if (element.parentField.owner != null &&
          element.parentField.owner.name.contains('&')) continue;

      String referenceName;
      String owningAllocator; // Class or library that allocated.
      bool owningAllocatorIsAbstract;

      switch (element.parentField.runtimeType.toString()) {
        case 'ClassRef':
          final ClassRef classRef = element.classRef;
          owningAllocator = classRef.name;
          // TODO(terry): Quick way to detect if class is probably abstract-
          // TODO(terry): Does it exist in the class list table?
          owningAllocatorIsAbstract = _searchClass(owningAllocator) == null;
          break;
        case 'FieldRef':
          final FieldRef fieldRef = element.fieldRef;
          referenceName = fieldRef.name;
          switch (fieldRef.owner.runtimeType.toString()) {
            case 'ClassRef':
              final ClassRef classRef = ClassRef.parse(fieldRef.owner.json);
              owningAllocator = classRef.name;
              // TODO(terry): Quick way to detect if class is probably abstract-
              // TODO(terry): Does it exist in the class list table?
              owningAllocatorIsAbstract = _searchClass(owningAllocator) == null;
              break;
            case 'Library':
            case 'LibraryRef':
              final Library library = Library.parse(fieldRef.owner.json);
              owningAllocator =
                  'Library ${library != null ? library.name : ""}';
              break;
          }
          break;
        case 'FuncRef':
          print('Error: Unhandled ${element.parentField.runtimeType}');
          // TODO(terry): TBD
          // final FuncRef funcRef = element.funcRef;
          break;
        case 'Instance':
          print('Error: Unhandled ${element.parentField.runtimeType}');
          // TODO(terry): TBD
          // final Instance instance = element.instance;
          break;
        case 'InstanceRef':
          print('Error: Unhandled ${element.parentField.runtimeType}');
          // TODO(terry): TBD
          // final InstanceRef instanceRef = element.instanceRef;
          break;
        case 'Library':
        case 'LibraryRef':
          print('Error: Unhandled ${element.parentField.runtimeType}');
          // TODO(terry): TBD
          // final Library library = element.library;
          break;
        case 'NullVal':
        case 'NullValRef':
          print('Error: Unhandled ${element.parentField.runtimeType}');
          // TODO(terry): TBD
          // final NullVal nullValue = element.nullVal;
          break;
        case 'Obj':
        case 'ObjRef':
          print('Error: Unhandled ${element.parentField.runtimeType}');
          // TODO(terry): TBD
          // final Obj obj = element.obj;
          break;
        default:
          print('ERROR: Unhandled inbound ${element.parentField.runtimeType}');
      }

      final CoreElement liElem = li(c: 'allocation-li')
        ..add([
          span(text: 'class $owningAllocator', c: 'allocated-by-class'),
          span(text: 'field $referenceName', c: 'ref-by')
        ]);
      if (owningAllocatorIsAbstract) {
        // Mark as grayed/italic
        liElem.clazz('li-allocation-abstract');
      }
      if (!owningAllocatorIsAbstract && owningAllocator.isNotEmpty) {
        // TODO(terry): Expensive for each hover need better VMService identity.
        // Get hashCode identity object id changes but hashCode is our identity.
        final hashCodeResult = await evaluate(hover.data.objectRef, 'hashCode');
        liElem.setAttribute('data-hashcode', hashCodeResult.valueAsString);

        liElem.setAttribute('data-owning-class', owningAllocator);
        liElem.setAttribute('data-ref', referenceName);
      }
      liElem.onClick.listen((evt) {
        final html.Element e = evt.currentTarget;

        String className = e.getAttribute('data-owning-class');
        if (className == null || className.isEmpty) {
          className = e.parent.getAttribute('data-owning-class');
        }
        String refName = e.getAttribute('data-ref');
        if (refName == null || refName.isEmpty) {
          refName = e.parent.getAttribute('data-ref');
        }
        String objectHashCode = e.getAttribute('data-hashcode');
        if (objectHashCode == null || objectHashCode.isEmpty) {
          objectHashCode = e.parent.getAttribute('data-hashcode');
        }

        // Done with the hover - close it down.
        instancePopup.clear(); // Remove all children.
        instancePopup.element.style.display = 'none';

        // Make sure its a known class (not abstract).
        if (className.isNotEmpty &&
            refName.isNotEmpty &&
            objectHashCode.isNotEmpty) {
          // Display just the instances of classes with ref
          selectClassAndInstanceInField(className, refName, objectHashCode);
        }
      });
      ulElem.add(liElem);
    }

    if (hover.cell != null && hover.cell.hasClass('allocation')) {
      // Hover over
      final int top = hover.cell.top + 10;
      final int left = hover.cell.left + 21;

      instancePopup.clear(); // TODO(terry): Workaround multiple ULs?

      instancePopup.add(ulElem);

      hover.cell.add(instancePopup);

      // Display the popup.
      instancePopup
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

      if (ref.valueAsString != null && !ref.valueAsStringIsTruncated) {
        return ref.valueAsString;
      } else {
        // TOOD(terry): Shouldn't happen but want to check - remove later.
        return 'UNKNOWN BoundField value';
      }
    };

    memoryDataView = MemoryDataView(memoryController, describer);

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
  NavigationState._()
      : _className = '',
        _hashCode = '';
  NavigationState.classSelect(this._className) : _hashCode = '';
  NavigationState.instanceSelect(this._className, this._hashCode);

  static const String dataIndex = 'data-index';
  static const String dataClass = 'data-class';
  static const String dataField = 'data-field';
  static const String dataHashCode = 'data-hashcode';

  final String _className;
  final String _hashCode;

  String field = '';

  String get className => _className;
  String get objectHashCode => _hashCode;

  bool get isClass =>
      _className.isNotEmpty && field.isEmpty && _hashCode.isEmpty;
  bool get isInstance =>
      _className.isNotEmpty && field.isEmpty && _hashCode.isNotEmpty;
  bool get isInbound =>
      _className.isNotEmpty && field.isNotEmpty && _hashCode.isNotEmpty;

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
    if (objectHashCode.isNotEmpty) {
      spanElem.setAttribute(dataHashCode, objectHashCode);
    }

    return spanElem;
  }

  CoreElement get separator => span(text: '>', c: 'history-separator');
}

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
        assert(state.objectHashCode == stateToRemove.objectHashCode &&
            state.className == stateToRemove.className &&
            state.field == stateToRemove.field);
        _path.removeRange(row, _path.length);
        return;
      }
    }
  }

  // Last item in path an inBound NavigationState.
  bool get isLastInBound => _path.isNotEmpty ? _path.last.isInbound : false;

  bool get isLastInstance => _path.isNotEmpty ? _path.last.isInstance : false;

  void addPathsLinks(CoreElement parent, [clickHandler]) {
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
