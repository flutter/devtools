// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler_controller.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table_controller.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/test_data/cpu_profiler/simple_profile_1.dart';
import '../../test_infra/test_data/cpu_profiler/simple_profile_2.dart';

void main() {
  group('$MethodTableController', () {
    late MethodTableController controller;

    setUp(() {
      controller = MethodTableController(
        dataNotifier: FixedValueListenable<CpuProfileData>(
          CpuProfileData.empty(),
        ),
      );
    });

    Future<CpuProfileData> initSingleRootData({
      required Map<String, dynamic> dataJson,
      required String profileGolden,
    }) async {
      final data = CpuProfileData.fromJson(dataJson);
      await CpuProfileTransformer().processData(data, processId: 'test');
      expect(data.callTreeRoots.length, 1);
      expect(data.callTreeRoots.first.profileAsString(), profileGolden);
      return data;
    }

    Future<CpuProfileData> initSimpleData1() async {
      return await initSingleRootData(
        dataJson: simpleCpuProfile1,
        profileGolden: simpleProfile1Golden,
      );
    }

    Future<CpuProfileData> initSimpleData2() async {
      return await initSingleRootData(
        dataJson: simpleCpuProfile2,
        profileGolden: simpleProfile2Golden,
      );
    }

    test('createMethodTableGraph ', () async {
      var data = await initSimpleData1();

      expect(controller.methods.value, isEmpty);
      controller.createMethodTableGraph(data);
      expect(controller.methods.value.length, 4);
      expect(controller.graphAsString(), simpleProfile1MethodTableGolden);

      controller.reset();
      data = await initSimpleData2();

      expect(controller.methods.value, isEmpty);
      controller.createMethodTableGraph(data);
      expect(controller.methods.value.length, 5);
      expect(controller.graphAsString(), simpleProfile2MethodTableGolden);
    });

    test('createMethodTableGraph with user tags ', () async {
      final data = CpuProfileData.fromJson(simpleCpuProfile1);
      final fullDataPair = CpuProfilePair(
        functionProfile: data,
        codeProfile: null,
      );
      final cpuProfilePair = CpuProfilePair.withTagRoots(
        fullDataPair,
        CpuProfilerTagType.user,
      );
      await cpuProfilePair.process(
        transformer: CpuProfileTransformer(),
        processId: 'test',
      );

      final processedData = cpuProfilePair.functionProfile;
      expect(processedData.callTreeRoots.length, 2);
      expect(
        processedData.cpuProfileRoot.profileAsString(),
        simpleProfile1GroupedByTagGolden,
      );

      expect(controller.methods.value, isEmpty);
      controller.createMethodTableGraph(processedData);
      expect(controller.methods.value.length, 4);
      expect(controller.graphAsString(), simpleProfile1MethodTableGolden);
    });

    test('selectedNode updates', () async {
      final data = await initSimpleData1();
      controller.createMethodTableGraph(data);

      expect(controller.selectedNode.value, isNull);
      controller.selectedNode.value = controller.methods.value.first;
      expect(controller.selectedNode.value, controller.methods.value.first);
      controller.selectedNode.value = controller.methods.value[2];
      expect(controller.selectedNode.value, controller.methods.value[2]);

      controller.reset();
      expect(controller.selectedNode.value, isNull);
    });

    test('matchesForSearch', () async {
      final data = await initSimpleData2();
      controller.createMethodTableGraph(data);

      expect(controller.matchesForSearch(''), isEmpty);
      expect(controller.matchesForSearch('a.dart|b.dart').length, 2);
      expect(controller.matchesForSearch('package:my_app').length, 5);
      expect(controller.matchesForSearch('some_bogus_search'), isEmpty);
    });

    group('caller and callee percentage', () {
      late List<MethodTableGraphNode> methods;

      setUp(() async {
        final data = await initSimpleData1();
        controller.createMethodTableGraph(data);
        methods = controller.methods.value;
        expect(methods.length, 4);
      });

      test('when selected node is null', () {
        expect(controller.selectedNode.value, isNull);
        expect(controller.callerPercentageFor(methods[1]), 0.0);
        expect(controller.calleePercentageFor(methods[1]), 0.0);
      });

      test('when node is disconnected', () {
        controller.selectedNode.value = methods.first;
        final selectedNode = controller.selectedNode.value!;
        expect(selectedNode.name, 'A');
        final disconnctedNode = methods[2];
        expect(disconnctedNode.name, 'C');

        expect(selectedNode.predecessors, isNot(contains(disconnctedNode)));
        expect(selectedNode.successors, isNot(contains(disconnctedNode)));

        expect(controller.callerPercentageFor(disconnctedNode), 0.0);
        expect(controller.calleePercentageFor(disconnctedNode), 0.0);
      });

      test('when node is connected', () {
        final a = methods[0];
        final b = methods[1];
        final c = methods[2];
        final d = methods[3];

        controller.selectedNode.value = a;
        expect(controller.callerPercentageFor(a), 0.0);
        expect(controller.callerPercentageFor(b), 0.0);
        expect(controller.callerPercentageFor(c), 0.0);
        expect(controller.callerPercentageFor(d), 0.0);
        expect(controller.calleePercentageFor(a), 0.0);
        expect(controller.calleePercentageFor(b), 0.7777777777777778);
        expect(controller.calleePercentageFor(c), 0.0);
        expect(controller.calleePercentageFor(d), 0.2222222222222222);

        controller.selectedNode.value = b;
        expect(controller.callerPercentageFor(a), 1.0);
        expect(controller.callerPercentageFor(b), 0.0);
        expect(controller.callerPercentageFor(c), 0.0);
        expect(controller.callerPercentageFor(d), 0.0);
        expect(controller.calleePercentageFor(a), 0.0);
        expect(controller.calleePercentageFor(b), 0.0);
        expect(controller.calleePercentageFor(c), 1.0);
        expect(controller.calleePercentageFor(d), 0.0);

        controller.selectedNode.value = c;
        expect(controller.callerPercentageFor(a), 0.0);
        expect(controller.callerPercentageFor(b), 0.6666666666666666);
        expect(controller.callerPercentageFor(c), 0.0);
        expect(controller.callerPercentageFor(d), 0.3333333333333333);
        expect(controller.calleePercentageFor(a), 0.0);
        expect(controller.calleePercentageFor(b), 0.0);
        expect(controller.calleePercentageFor(c), 0.0);
        expect(controller.calleePercentageFor(d), 0.0);

        controller.selectedNode.value = d;
        expect(controller.callerPercentageFor(a), 1.0);
        expect(controller.callerPercentageFor(b), 0.0);
        expect(controller.callerPercentageFor(c), 0.0);
        expect(controller.callerPercentageFor(d), 0.0);
        expect(controller.calleePercentageFor(a), 0.0);
        expect(controller.calleePercentageFor(b), 0.0);
        expect(controller.calleePercentageFor(c), 1.0);
        expect(controller.calleePercentageFor(d), 0.0);
      });
    });
  });
}
