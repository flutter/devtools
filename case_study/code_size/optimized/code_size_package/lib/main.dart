import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:steel_crypt/steel_crypt.dart' as encrypt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unoptimized Encryption Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Unoptimized Encryption Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextEditingController textEditingController;
  late String encryptedText;

  @override
  void initState() {
    super.initState();
    encryptedText = '';
    textEditingController = TextEditingController(
      text: 'Lorem ipsum dolor sit amet',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            TextField(
              controller: textEditingController,
            ),
            Column(
              children: [
                ElevatedButton(
                  child: const Text('Encrypt'),
                  onPressed: () {
                    setState(() {
                      encryptedText = encryptText(textEditingController.text);
                    });
                  },
                ),
                TextButton(
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.black54),
                  ),
                  onPressed: () {
                    textEditingController.clear();
                    setState(() {
                      encryptedText = '';
                    });
                  },
                ),
              ],
            ),
            Column(
              children: [
                const Text(
                  'Encrypted Text:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(encryptedText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String encryptText(String stringToEncrypt) {
    final key = base64.encode(
      Uint8List.fromList(
        utf8.encode('my 32 length key................'),
      ),
    );
    final iv = base64.encode(Uint8List(16));
    final aesEncrypter =
        encrypt.AesCrypt(key: key, padding: encrypt.PaddingAES.pkcs7);
    final encryptedText = aesEncrypter.ctr.encrypt(
      inp: stringToEncrypt,
      iv: iv,
    );
    return encryptedText;
  }
}
