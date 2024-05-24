// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:devtools_app/src/shared/primitives/byte_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$Uint8ListRingBuffer', () {
    test('calculates size', () {
      final list1 = Uint8List.fromList([1, 2, 3, 4]);
      final list2 = Uint8List.fromList([5, 6, 7, 8]);
      final list3 = Uint8List.fromList([9, 10, 11, 12]);

      final buffer = Uint8ListRingBuffer(maxSizeBytes: 100);
      expect(buffer.size, 0);
      buffer.addData(list1);
      expect(buffer.size, 4);
      buffer.addData(list2);
      expect(buffer.size, 8);
      buffer.addData(list3);
      expect(buffer.size, 12);
    });

    test('can add data', () {
      final list1 = Uint8List.fromList([1, 2, 3, 4]);
      final list2 = Uint8List.fromList([5, 6, 7, 8]);
      final list3 = Uint8List.fromList([9, 10, 11, 12]);

      final buffer = Uint8ListRingBuffer(maxSizeBytes: 10);
      expect(buffer.data, isEmpty);

      buffer.addData(list1);
      expect(buffer.data.length, 1);
      expect(buffer.size, 4);
      expect(buffer.data, contains(list1));

      buffer.addData(list2);
      expect(buffer.data.length, 2);
      expect(buffer.size, 8);
      expect(buffer.data, contains(list1));
      expect(buffer.data, contains(list2));

      buffer.addData(list3);
      expect(buffer.data.length, 2);
      expect(buffer.size, 8);
      expect(buffer.data, isNot(contains(list1)));
      expect(buffer.data, contains(list2));
      expect(buffer.data, contains(list3));
    });

    test('can merge data', () {
      final list1 = Uint8List.fromList([1, 2, 3, 4]);
      final list2 = Uint8List.fromList([5, 6, 7, 8]);

      final buffer = Uint8ListRingBuffer(maxSizeBytes: 10);
      expect(buffer.data, isEmpty);

      buffer
        ..addData(list1)
        ..addData(list2);
      expect(buffer.size, 8);

      final merged = buffer.merged;
      expect(merged.length, 8);
      expect(merged, Uint8List.fromList([...list1, ...list2]));
    });

    test('can clear data', () {
      final list1 = Uint8List.fromList([1, 2, 3, 4]);
      final list2 = Uint8List.fromList([5, 6, 7, 8]);

      final buffer = Uint8ListRingBuffer(maxSizeBytes: 10);
      expect(buffer.data, isEmpty);

      buffer
        ..addData(list1)
        ..addData(list2);
      expect(buffer.data.length, 2);
      expect(buffer.size, 8);
      expect(buffer.data, contains(list1));
      expect(buffer.data, contains(list2));

      buffer.clear();
      expect(buffer.data, isEmpty);
      expect(buffer.size, 0);
    });
  });

  group('printBytes', () {
    test('${ByteUnit.kb}', () {
      const int kb = 1024;
      expect(printBytes(0, unit: ByteUnit.kb, fractionDigits: 0), '0');
      expect(printBytes(1, unit: ByteUnit.kb, fractionDigits: 0), '1');
      expect(printBytes(kb - 1, unit: ByteUnit.kb, fractionDigits: 0), '1');
      expect(printBytes(kb, unit: ByteUnit.kb, fractionDigits: 0), '1');
      expect(printBytes(kb + 1, unit: ByteUnit.kb, fractionDigits: 0), '2');
      expect(printBytes(2000, unit: ByteUnit.kb, fractionDigits: 0), '2');

      expect(printBytes(0, unit: ByteUnit.kb), '0.0');
      expect(printBytes(1, unit: ByteUnit.kb), '0.0');
      expect(printBytes(kb - 1, unit: ByteUnit.kb), '1.0');
      expect(printBytes(kb, unit: ByteUnit.kb), '1.0');
      expect(printBytes(kb + 1, unit: ByteUnit.kb), '1.0');
      expect(printBytes(2000, unit: ByteUnit.kb), '2.0');
    });

    test('${ByteUnit.mb}', () {
      const int mb = 1024 * 1024;

      expect(printBytes(10 * mb, unit: ByteUnit.mb, fractionDigits: 0), '10');
      expect(printBytes(10 * mb, unit: ByteUnit.mb), '10.0');
      expect(
        printBytes(10 * mb, unit: ByteUnit.mb, fractionDigits: 2),
        '10.00',
      );

      expect(
        printBytes(1000 * mb, unit: ByteUnit.mb, fractionDigits: 0),
        '1000',
      );
      expect(printBytes(1000 * mb, unit: ByteUnit.mb), '1000.0');
      expect(
        printBytes(1000 * mb, unit: ByteUnit.mb, fractionDigits: 2),
        '1000.00',
      );
    });

    test('${ByteUnit.gb}', () {
      expect(printBytes(1024, unit: ByteUnit.gb), '0.0');
      expect(printBytes(1024 * 1024, unit: ByteUnit.gb), '0.0');
      expect(printBytes(1024 * 1024 * 100, unit: ByteUnit.gb), '0.1');
      expect(printBytes(1024 * 1024 * 1024, unit: ByteUnit.gb), '1.0');
    });
  });

  test('prettyPrintBytes', () {
    const int kb = 1024;
    const int mb = 1024 * kb;

    expect(prettyPrintBytes(51, includeUnit: true), '51 B');
    expect(prettyPrintBytes(52, includeUnit: true), '0.1 KB');

    expect(prettyPrintBytes(kb), '1.0');
    expect(prettyPrintBytes(kb + 100), '1.1');
    expect(prettyPrintBytes(kb + 150, kbFractionDigits: 2), '1.15');
    expect(prettyPrintBytes(kb, includeUnit: true), '1.0 KB');
    expect(prettyPrintBytes(kb * 1000, includeUnit: true), '1000.0 KB');

    expect(prettyPrintBytes(mb), '1.0');
    expect(prettyPrintBytes(mb + kb * 100), '1.1');
    expect(prettyPrintBytes(mb + kb * 150, mbFractionDigits: 2), '1.15');
    expect(prettyPrintBytes(mb, includeUnit: true), '1.0 MB');
    expect(prettyPrintBytes(mb - kb, includeUnit: true), '1023.0 KB');
  });

  test('convertBytes', () {
    // Number of bytes in 1 GB
    const bytesInGb = 1024 * 1024 * 1024;
    const kbInGb = 1024 * 1024;
    const mbInGb = 1024;

    expect(convertBytes(bytesInGb, to: ByteUnit.byte), bytesInGb);
    expect(convertBytes(bytesInGb, to: ByteUnit.kb), kbInGb);
    expect(convertBytes(bytesInGb, to: ByteUnit.mb), mbInGb);
    expect(convertBytes(bytesInGb, to: ByteUnit.gb), 1);

    expect(
      convertBytes(kbInGb, from: ByteUnit.kb, to: ByteUnit.byte),
      bytesInGb,
    );
    expect(convertBytes(kbInGb, from: ByteUnit.kb, to: ByteUnit.kb), kbInGb);
    expect(convertBytes(kbInGb, from: ByteUnit.kb, to: ByteUnit.mb), mbInGb);
    expect(convertBytes(kbInGb, from: ByteUnit.kb, to: ByteUnit.gb), 1);

    expect(
      convertBytes(mbInGb, from: ByteUnit.mb, to: ByteUnit.byte),
      bytesInGb,
    );
    expect(convertBytes(mbInGb, from: ByteUnit.mb, to: ByteUnit.kb), kbInGb);
    expect(convertBytes(mbInGb, from: ByteUnit.mb, to: ByteUnit.mb), mbInGb);
    expect(convertBytes(mbInGb, from: ByteUnit.mb, to: ByteUnit.gb), 1);

    expect(convertBytes(1, from: ByteUnit.gb, to: ByteUnit.byte), bytesInGb);
    expect(convertBytes(1, from: ByteUnit.gb, to: ByteUnit.kb), kbInGb);
    expect(convertBytes(1, from: ByteUnit.gb, to: ByteUnit.mb), mbInGb);
    expect(convertBytes(1, from: ByteUnit.gb, to: ByteUnit.gb), 1);
  });
}
