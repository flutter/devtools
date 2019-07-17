// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:meta/meta.dart';

import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import 'cpu_profile_flame_chart.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_tables.dart';

abstract class CpuProfiler extends CoreElement {
  CpuProfiler(
    this.flameChart,
    this.callTree,
    this.bottomUp, {
    this.defaultView = CpuProfilerViewType.flameChart,
  }) : super('div') {
    layoutVertical();
    flex();

    add(views = [
      flameChart,
      callTree,
      bottomUp,
    ]);

    // Hide views that are not the default view.
    for (CpuProfilerView v in views.where((view) => view.type != defaultView)) {
      v.hide();
    }
    _selectedViewType = defaultView;
  }

  CpuFlameChart flameChart;

  CpuBottomUp bottomUp;

  CpuCallTree callTree;

  CpuProfilerViewType defaultView;

  List<CpuProfilerView> views;

  CpuProfilerViewType _selectedViewType;

  bool showingMessage = false;

  void showView(CpuProfilerViewType showType) {
    _selectedViewType = showType;

    // If we are showing a message, we do not want to show any other views.
    if (showingMessage) return;

    CpuProfilerView viewToShow;
    for (CpuProfilerView view in views) {
      if (view.type == showType) {
        viewToShow = view;
      } else {
        view.hide();
      }
    }

    // Show the view after hiding the others.
    viewToShow.show();
  }

  void hideAll() {
    for (CpuProfilerView view in views) {
      view.hide();
    }
  }

  Future<void> update() async {
    reset();

    final Spinner spinner = Spinner.centered();
    try {
      add(spinner);

      await prepareCpuProfile();

      final showingMessage = maybeShowMessageOnUpdate();
      if (showingMessage) return;

      for (CpuProfilerView view in views) {
        view.update();
      }

      // Ensure we are showing the selected profiler view.
      showView(_selectedViewType);
    } catch (e) {
      showMessage(div(text: 'Error retrieving CPU profile: ${e.toString()}'));
    } finally {
      spinner.remove();
    }
  }

  void reset() {
    for (CpuProfilerView view in views) {
      view.reset();
    }
    _removeMessage();
  }

  Future<void> prepareCpuProfile();

  /// Returns true if we are showing a message instead of the profile.
  bool maybeShowMessageOnUpdate();

  void showMessage(CoreElement message) {
    hideAll();
    showingMessage = true;
    add(message
      ..id = 'cpu-profiler-message'
      ..clazz('centered-single-line-message'));
  }

  void _removeMessage() {
    element.children.removeWhere((e) => e.id == 'cpu-profiler-message');
    showingMessage = false;
  }
}

typedef CpuProfileDataProvider = CpuProfileData Function();

abstract class CpuProfilerView extends CoreElement {
  CpuProfilerView(this.type, this.profileDataProvider)
      : super('div', classes: 'fill-section');

  final CpuProfilerViewType type;

  final CpuProfileDataProvider profileDataProvider;

  bool viewNeedsRebuild = false;

  void rebuildView();

  void reset();

  void update({bool showLoadingSpinner = false}) async {
    if (profileDataProvider() == null) return;

    // Update the view if it is visible. Otherwise, mark the view as needing a
    // rebuild.
    if (!isHidden) {
      if (showLoadingSpinner) {
        final Spinner spinner = Spinner.centered();
        add(spinner);

        // Awaiting this future ensures the spinner pops up in between switching
        // profiler views. Without this, the UI is laggy and the spinner never
        // appears.
        await Future.delayed(const Duration(microseconds: 1));

        rebuildView();
        spinner.remove();
      } else {
        rebuildView();
      }
    } else {
      viewNeedsRebuild = true;
    }
  }

  void show() {
    hidden(false);
    if (viewNeedsRebuild) {
      viewNeedsRebuild = false;
      update(showLoadingSpinner: true);
    }
  }

  void hide() => hidden(true);
}

enum CpuProfilerViewType {
  flameChart,
  bottomUp,
  callTree,
}

class CpuProfilerTabNav {
  CpuProfilerTabNav(this.cpuProfiler, this.tabOrder) {
    _init();
  }

  final CpuProfiler cpuProfiler;

  final CpuProfilerTabOrder tabOrder;

  PTabNav get element => _tabNav;

  PTabNav _tabNav;

  PTabNavTab selectedTab;

  void _init() {
    final tabs = [
      CpuProfilerTab(
        'CPU Flame Chart',
        CpuProfilerViewType.flameChart,
      ),
      CpuProfilerTab(
        'Call Tree',
        CpuProfilerViewType.callTree,
      ),
      CpuProfilerTab(
        'Bottom Up',
        CpuProfilerViewType.bottomUp,
      )
    ];

    _tabNav = PTabNav(<CpuProfilerTab>[
      selectedTab = tabs.firstWhere((tab) => tab.type == tabOrder.first),
      tabs.firstWhere((tab) => tab.type == tabOrder.second),
      tabs.firstWhere((tab) => tab.type == tabOrder.third),
    ])
      ..element.style.borderBottom = '0';

    _tabNav.onTabSelected.listen((PTabNavTab tab) {
      // Return early if this tab is already selected.
      if (tab == selectedTab) {
        return;
      }
      selectedTab = tab;
      cpuProfiler.showView((tab as CpuProfilerTab).type);
    });
  }
}

class CpuProfilerTab extends PTabNavTab {
  CpuProfilerTab(String name, this.type) : super(name);

  final CpuProfilerViewType type;
}

class CpuProfilerTabOrder {
  CpuProfilerTabOrder({
    @required this.first,
    @required this.second,
    @required this.third,
  });
  final CpuProfilerViewType first;

  final CpuProfilerViewType second;

  final CpuProfilerViewType third;
}
