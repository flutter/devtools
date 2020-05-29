// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

const dialogDefault = 'dialog';

/// A FlatButton used to close a containing dialog - Cancel.
class DialogCancelButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FlatButton(
      onPressed: () {
        Navigator.of(context).pop(dialogDefault);
      },
      child: const Text('Cancel'),
    );
  }
}

/// A FlatButton used to close a containing dialog - Cancel.
class DialogOkButton extends StatelessWidget {
  const DialogOkButton(this.onOk) : super();

  final Function onOk;

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      onPressed: () {
        if (onOk != null) onOk();
        Navigator.of(context).pop(dialogDefault);
      },
      child: const Text('OK'),
    );
  }
}
