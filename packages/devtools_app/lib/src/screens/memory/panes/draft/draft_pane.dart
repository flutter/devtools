import 'package:flutter/material.dart';

class DraftPane extends StatefulWidget {
  const DraftPane({Key? key}) : super(key: key);

  @override
  State<DraftPane> createState() => _DraftPaneState();
}

class _DraftPaneState extends State<DraftPane> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('hello!!'),
      ],
    );
  }
}
