// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

const testAllocationData = r'''
{"allocations": {"version": 2, "dartDevToolsScreen": "memory", "data": [
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/1","name":"AClass"},"bytesCurrent":10000,"accumulatedSize":100,"instancesCurrent":10,"instancesAccumulated":10,"_new":[10,10000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/2","name":"BClass"},"bytesCurrent":20000,"accumulatedSize":200,"instancesCurrent":20,"instancesAccumulated":20,"_new":[20,20000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/3","name":"CClass"},"bytesCurrent":30000,"accumulatedSize":300,"instancesCurrent":30,"instancesAccumulated":30,"_new":[30,30000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/4","name":"DClass"},"bytesCurrent":40000,"accumulatedSize":400,"instancesCurrent":40,"instancesAccumulated":40,"_new":[40,40000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/5","name":"EClass"},"bytesCurrent":50000,"accumulatedSize":500,"instancesCurrent":50,"instancesAccumulated":50,"_new":[50,50000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/6","name":"FClass"},"bytesCurrent":60000,"accumulatedSize":600,"instancesCurrent":60,"instancesAccumulated":60,"_new":[60,60000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/7","name":"GClass"},"bytesCurrent":70000,"accumulatedSize":700,"instancesCurrent":70,"instancesAccumulated":70,"_new":[70,70000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/8","name":"HClass"},"bytesCurrent":80000,"accumulatedSize":800,"instancesCurrent":80,"instancesAccumulated":80,"_new":[80,80000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/9","name":"IClass"},"bytesCurrent":90000,"accumulatedSize":900,"instancesCurrent":90,"instancesAccumulated":90,"_new":[90,90000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/10","name":"JClass"},"bytesCurrent":100000,"accumulatedSize":1000,"instancesCurrent":5,"instancesAccumulated":2,"_new":[5,100000,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/11","name":"KClass"},"bytesCurrent":1111,"accumulatedSize":11,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,1111,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/12","name":"LClass"},"bytesCurrent":2222,"accumulatedSize":22,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,2222,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/13","name":"MClass"},"bytesCurrent":3333,"accumulatedSize":33,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,3333,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/14","name":"NClass"},"bytesCurrent":4444,"accumulatedSize":44,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,4444,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/15","name":"OClass"},"bytesCurrent":5555,"accumulatedSize":55,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,5555,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/16","name":"PClass"},"bytesCurrent":6666,"accumulatedSize":66,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,6666,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/17","name":"QClass"},"bytesCurrent":7777,"accumulatedSize":77,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,7777,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/18","name":"RClass"},"bytesCurrent":8888,"accumulatedSize":99,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,8888,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/19","name":"SClass"},"bytesCurrent":9999,"accumulatedSize":99,"instancesCurrent":50,"instancesAccumulated":0,"_new":[50,9999,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/20","name":"TClass"},"bytesCurrent":10,"accumulatedSize":0,"instancesCurrent":5,"instancesAccumulated":1,"_new":[5,10,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/21","name":"UClass"},"bytesCurrent":20,"accumulatedSize":0,"instancesCurrent":5,"instancesAccumulated":2,"_new":[5,20,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/22","name":"VClass"},"bytesCurrent":30,"accumulatedSize":0,"instancesCurrent":5,"instancesAccumulated":3,"_new":[5,30,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/23","name":"WClass"},"bytesCurrent":40,"accumulatedSize":0,"instancesCurrent":5,"instancesAccumulated":5,"_new":[5,40,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/24","name":"XClass"},"bytesCurrent":50,"accumulatedSize":0,"instancesCurrent":5,"instancesAccumulated":1,"_new":[5,50,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/24","name":"YClass"},"bytesCurrent":60,"accumulatedSize":0,"instancesCurrent":5,"instancesAccumulated":2,"_new":[5,60,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/24","name":"ZClass"},"bytesCurrent":70,"accumulatedSize":0,"instancesCurrent":5,"instancesAccumulated":3,"_new":[5,70,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/27","name":"AnotherClass"},"bytesCurrent":88,"accumulatedSize":0,"instancesCurrent":55,"instancesAccumulated":0,"_new":[55,88,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/28","name":"OneMoreClass"},"bytesCurrent":91,"accumulatedSize":0,"instancesCurrent":55,"instancesAccumulated":0,"_new":[55,91,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/28","name":"SecondClass"},"bytesCurrent":99,"accumulatedSize":0,"instancesCurrent":55,"instancesAccumulated":0,"_new":[55,99,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/29","name":"OneClass"},"bytesCurrent":111,"accumulatedSize":0,"instancesCurrent":55,"instancesAccumulated":0,"_new":[55,111,0],"_old":[0,0,0]},
  {"type":"ClassHeapStats","class":{"type":"@Class","fixedId":true,"id":"classes/30","name":"LastClass"},"bytesCurrent":222,"accumulatedSize":0,"instancesCurrent":55,"instancesAccumulated":0,"_new":[55,222,0],"_old":[0,0,0]}
]
}}
''';
