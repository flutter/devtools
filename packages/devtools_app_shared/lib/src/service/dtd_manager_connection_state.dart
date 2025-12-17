// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// A class representing the current state of a DTD connection.
sealed class DTDConnectionState {}

/// DTD is not connected and has not started to connect.
class NotConnectedDTDState extends DTDConnectionState {}

/// Attempting to connect to DTD.
class ConnectingDTDState extends DTDConnectionState {}

/// A connection failed and we are waiting for [seconds] before
/// trying again.
///
/// This state is emitted every second during a retry countdown.
class WaitingToRetryDTDState extends DTDConnectionState {
  WaitingToRetryDTDState(this.seconds);

  /// The remaining number of seconds to wait.
  ///
  /// This value does not update, but the state is emitted for each second of
  /// a retry countdown.
  final int seconds;
}

/// We are connected to DTD.
class ConnectedDTDState extends DTDConnectionState {}

/// We failed to connect to DTD in the maximum number of retries and are no
/// longer trying to connect.
class ConnectionFailedDTDState extends DTDConnectionState {}
