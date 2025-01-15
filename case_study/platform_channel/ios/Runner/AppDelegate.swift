// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  var messageChannel: FlutterBasicMessageChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    guard let controller = self.window.rootViewController as? FlutterViewController else {
        assertionFailure("Controller not of type FlutterViewController")
        return false
    }
    messageChannel = FlutterBasicMessageChannel(
      name: "shuttle",
      binaryMessenger: controller.binaryMessenger,
      codec: FlutterStringCodec.sharedInstance())
    messageChannel?.setMessageHandler({
      (message: Any?, reply: FlutterReply) in
      reply("Done!")
      sleep(2)
      self.messageChannel?.sendMessage("From native iOS")
    })
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
