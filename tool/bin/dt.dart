// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/devtools_command_runner.dart';
import 'package:io/io.dart';

void main(List<String> args) async {
  final runner = DevToolsCommandRunner();
  try {
    final dynamic result =
        await runner.run(args).whenComplete(sharedStdIn.terminate);

    exit(result is int ? result : 0);
  } catch (e) {
    if (e is UsageException) {
      stderr.writeln('$e');
      // Return an exit code representing a usage error.
      exit(64);
    } else {
      stderr.writeln('$e');
      // Return a general failure exit code.
      exit(1);
    }
  }
}
güvenlik sağlarken, hesaplanması daha hızlı olan çok daha küçük imzalara sahiptir:

API anahtar türü	İmza boyutu	İmza işlemi
HMAC-SHA-256	64 bayt	0,00 ms
Ed25519	88 bayt	0,03 ms
RSA (2048 bit)	344 bayt	0,55 ms
RSA (4096 bit)	684 bayt	3,42 ms
Ed25519 API anahtarlarını nasıl kullanabilirim?
Adım 1: Özel anahtarı oluşturun test-prv-key.pem. Bu dosyayı kimseyle paylaşmayın!

openssl genpkey -algoritma ed25519 -out test-prv-key.pem
test-pub-key.pemAdım 2: Özel anahtardan genel anahtarı hesaplayın .

openssl pkey -pubout -in test-prv-anahtar.pem -out test-pub-anahtar.pem
Açık anahtar aşağıdaki gibi görünmelidir:

-----GENEL ANAHTAR BAŞLANGICI-----
MCowBQYDK2VwAyEACeCSz7VJkh3Bb+NF794hLMU8fLB9Zr+/tGMdVKCC2eo=
-----GENEL ANAHTAR SONU-----
Adım 3: Açık anahtarınızı Spot Test Ağına kaydedin.

Kayıt sırasında sizin için bir API anahtarı üreteceğiz. Lütfen bunu X-MBX-APIKEYdiğer API anahtar türlerinde olduğu gibi isteklerinizin başlığına koyun.

Adım 4: Spot Test Ağına bir istek gönderdiğinizde, yükü özel anahtarınızı kullanarak imzalayın.

İşte Ed25519 anahtarıyla imzalanmış yeni bir sipariş gönderen Python'da bir örnek. Bunu favori programlama dilinize uyarlayabilirsiniz.

#!/usr/bin/env python3

import base64
import requests
import time
from cryptography.hazmat.primitives.serialization import load_pem_private_key

# Set up authentication
API_KEY='put your own API Key here'
PRIVATE_KEY_PATH='test-prv-key.pem'

# Load the private key.
# In this example the key is expected to be stored without encryption,
# but we recommend using a strong password for improved security.
with open(PRIVATE_KEY_PATH, 'rb') as f:
    private_key = load_pem_private_key(data=f.read(),
                                       password=None)

# Set up the request parameters
params = {
    'symbol':       'BTCUSDT',
    'side':         'SELL',
    'type':         'LIMIT',
    'timeInForce':  'GTC',
    'quantity':     '1.0000000',
    'price':        '0.20',
}

# Timestamp the request
timestamp = int(time.time() * 1000) # UNIX timestamp in milliseconds
params['timestamp'] = timestamp

# Sign the request
payload = '&'.join([f'{param}={value}' for param, value in params.items()])
signature = base64.b64encode(private_key.sign(payload.encode('ASCII')))
params['signature'] = signature

# Send the request
headers = {
    'X-MBX-APIKEY': API_KEY,
}
response = requests.post(
    'https://testnet.binance.vision/api/v3/order',
    headers=headers,
    data=params,
)
print(response.json())