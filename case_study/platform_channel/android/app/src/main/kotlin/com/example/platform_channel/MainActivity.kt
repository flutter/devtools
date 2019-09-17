package com.example.platform_channel

import android.os.Bundle

import io.flutter.app.FlutterActivity
import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.StringCodec;
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    GeneratedPluginRegistrant.registerWith(this)
    var channel: BasicMessageChannel<String> = BasicMessageChannel<String>(getFlutterView(), "shuttle", StringCodec.INSTANCE)
    channel.setMessageHandler({ message, reply ->
      try {
        reply.reply("Done!")
        Thread.sleep(2000)
        channel.send("Response from Java")
      } catch (e: Exception) {}
    })
  }
}
