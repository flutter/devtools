// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../globals.dart';
import '../debugger_state.dart';

class DebuggerScreen extends Screen {
  const DebuggerScreen() : super(DevToolsScreenType.debugger);

  @override
  Widget build(BuildContext context) {
    return DebuggerScreenBody();
  }

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Debugger',
      icon: Icon(Octicons.bug),
    );
  }
}

class DebuggerScreenBody extends StatefulWidget {
  @override
  DebuggerScreenBodyState createState() => DebuggerScreenBodyState();
}

class DebuggerScreenBodyState extends State<DebuggerScreenBody> {
  DebuggerState debuggerState;
  Script script;

  @override
  void initState() {
    super.initState();
    debuggerState = DebuggerState();
    debuggerState.setVmService(serviceManager.service);
    serviceManager.service
        .getScripts(serviceManager.isolateManager.selectedIsolate.id)
        .then((scripts) async {
      final scriptRef = scripts.scripts
          .where((ref) => ref.uri.contains('package:flutter'))
          .first;
      print('script ref ${scriptRef.uri} found');
      final _script = await serviceManager.service.getObject(
        serviceManager.isolateManager.selectedIsolate.id,
        scriptRef.id,
      ) as Script;
      print('${_script.library} loaded');
      setState(() => script = _script);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFirstFraction: 0.25,
      firstChild: const Text('Debugger details'),
      secondChild: CodeView(
        script: script,
      ),
    );
  }
}

class CodeView extends StatelessWidget {
  const CodeView({Key key, this.script}) : super(key: key);

  final Script script;

  @override
  Widget build(BuildContext context) {
    if (script == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return DefaultTextStyle(
      style: Theme.of(context)
          .textTheme
          .bodyText2
          .copyWith(fontFamily: 'RobotoMono'),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(script.source),
        ),
      ),
    );
  }
}
