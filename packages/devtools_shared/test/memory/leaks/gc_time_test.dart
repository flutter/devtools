import 'package:devtools_shared/src/memory/leaks/_gc_time.dart';

import 'package:test/test.dart';

void main() {
  test('Cycles happen as expected.', () {
    final gcTime = GCTimeLine();
    expect(gcTime.now, 1);
    gcTime.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
    expect(gcTime.now, 1);
    gcTime.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
    expect(gcTime.now, 1);
    gcTime.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
    expect(gcTime.now, 1);
    gcTime.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
    expect(gcTime.now, 2);
    gcTime.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
    expect(gcTime.now, 2);
    gcTime.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
    expect(gcTime.now, 2);
    gcTime.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
    expect(gcTime.now, 2);
    gcTime.registerGCEvent({GCEvent.newGC, GCEvent.oldGC});
    expect(gcTime.now, 3);
  });
}
