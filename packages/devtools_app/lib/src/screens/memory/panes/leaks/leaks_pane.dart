import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/eval_on_dart_library.dart';
import '../../../../shared/globals.dart';

class LeaksPane extends StatefulWidget {
  const LeaksPane({Key? key}) : super(key: key);

  @override
  State<LeaksPane> createState() => _LeaksPaneState();
}

class _LeaksPaneState extends State<LeaksPane> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Memory leak tracking functionality will be here.'),
      ],
    );
  }
}
