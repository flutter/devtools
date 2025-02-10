// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Constants for RPC methods and parameters handled by [InteractionDelegate].
abstract class InteractionDelegateConstants {
  static const String kOnTapDown = 'onTapDown';
  static const String kOnTapUp = 'onTapUp';
  static const String kOnScroll = 'onScroll';
  static const String kOnPanZoomStart = 'onPanZoomStart';
  static const String kOnPanZoomUpdate = 'onPanZoomUpdate';
  static const String kOnPanZoomEnd = 'onPanZoomEnd';
  static const String kOnKeyUpEvent = 'onKeyUpEvent';
  static const String kOnKeyDownEvent = 'onKeyDownEvent';
  static const String kOnKeyRepeatEvent = 'onKeyRepeatEvent';
  static const String kOnPointerMove = 'onPointerMove';
  static const String kOnPointerHover = 'onPointerHover';

  static const String kLocalPositionX = 'localPositionX';
  static const String kLocalPositionY = 'localPositionY';
  static const String kDeltaX = 'deltaX';
  static const String kDeltaY = 'deltaY';
  static const String kKeyId = 'keyId';
  static const String kPhysicalKeyId = 'usbHidUsage';
  static const String kButtons = 'buttons';
  static const String kCharacter = 'character';
}