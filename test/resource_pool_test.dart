import 'dart:async';

import 'package:resource_pool/resource_pool.dart';
import 'package:test/test.dart';

void main() {
  final resource0 = "resource0";

  test("client can get available resource from pool", () async {
    final pool = ResourcePool<String>(1, () async => resource0);

    final resource = await pool.get();
    expect(resource, resource0);
    expect(pool.availableResourceCount, 0);
    expect(pool.busyResourceCount, 1);
  });

  test("client can return resource to pool", () async {
    final pool = ResourcePool<String>(1, () async => resource0);

    final client0Resource = await pool.get();

    pool.release(client0Resource);

    expect(pool.availableResourceCount, 1);
    expect(pool.busyResourceCount, 0);
  });

  test("client should wait for available resource if pool is out of capacity", () async {
    var resourcesCreated = 0;

    final pool = ResourcePool<String>(1, () async {
      resourcesCreated++;
      await Future.delayed(Duration(milliseconds: 10));
      return resource0;
    });

    final client0ResourceFuture = pool.get();
    final client1ResourceFuture = pool.get();

    expect(resourcesCreated, 1);
    expect(pool.queueSize, 1);
    expect(pool.availableResourceCount, 0);

    final client0Resource = await client0ResourceFuture;
    expect(pool.busyResourceCount, 1);

    pool.release(client0Resource);

    final client1Resource = await client1ResourceFuture;

    expect(client1Resource, resource0);
    expect(pool.queueSize, 0);
    expect(pool.availableResourceCount, 0);
    expect(pool.busyResourceCount, 1);
  });

  test("client can take resources from pool with larger capacity", () async {
    var resourceNumber = 0;
    final pool = ResourcePool<String>(2, () async => "resource${resourceNumber++}");

    final resource0 = await pool.get();
    expect(resource0, "resource0");
    expect(pool.availableResourceCount, 0);
    expect(pool.busyResourceCount, 1);

    final resource1 = await pool.get();
    expect(resource1, "resource1");
    expect(pool.availableResourceCount, 0);
    expect(pool.busyResourceCount, 2);
  });

  test("pool should reuse previously released resource", () async {
    var resourceNumber = 0;
    final pool = ResourcePool<String>(2, () async => "resource${resourceNumber++}");

    var resource = await pool.get();
    pool.release(resource);

    resource = await pool.get();
    expect(resource, "resource0");
  });

  test("client max wait for available resource with timeout", () async {
    final pool = ResourcePool<String>(1, () async => resource0);

    await pool.get();

    expect(() async => await pool.get().timeout(Duration(milliseconds: 100)), throwsA(TypeMatcher<TimeoutException>()));
  });

  test("pool supports max waiting queue size", () async {
    final pool = ResourcePool<String>(1, () async => resource0, maxQueueSize: 1);

    // 1 - available
    await pool.get();

    // 2 -> in queue => queue size = 1
    // ignore: unawaited_futures
    pool.get();

    // 3 -> in queue and out of max queue size
    expect(() => pool.get(), throwsA("Max queue size reached: 1"));
  });

  test("pool throws exception when invalid resource is released", () async {
    final pool = ResourcePool<String>(1, () async => resource0);

    await pool.get();

    expect(() => pool.release("invalid resource"), throwsA("Pool does not own released resource"));
  });

  test("client can remove resource from pool", () async {
    var resourceNumber = 0;
    final pool = ResourcePool<String>(1, () async => "resource${resourceNumber++}");

    final resource0 = await pool.get();

    await pool.remove(resource0);

    expect(pool.availableResourceCount, 0);
    expect(pool.busyResourceCount, 0);

    final resource1 = await pool.get();

    expect(resource1, "resource1");
    expect(pool.availableResourceCount, 0);
    expect(pool.busyResourceCount, 1);
  });

  test("after resource is removed new resource must be created and provided for waiting client", () async {
    var resourceNumber = 0;
    final pool = ResourcePool<String>(1, () async => "resource${resourceNumber++}");

    final resource0 = await pool.get();

    // waiting for resource
    final resource1Future = pool.get();

    // old resource is removed
    await pool.remove(resource0);

    // new resource is created and provided to waiting client
    final resource1 = await resource1Future;

    expect(resource1, "resource1");
    expect(pool.availableResourceCount, 0);
    expect(pool.busyResourceCount, 1);
  });
}
