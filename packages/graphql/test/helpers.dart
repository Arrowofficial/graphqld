import 'dart:async';

import 'package:graphql/client.dart';

const debuggingUnexpectedTestFailures = false;

overridePrint(testFn(List<String> log)) => () {
      final log = <String>[];
      final spec = ZoneSpecification(print: (_, __, ___, String msg) {
        log.add(msg);
      });
      return Zone.current.fork(specification: spec).run(() => testFn(log));
    };

class TestCache extends GraphQLCache {
  bool get returnPartialData => debuggingUnexpectedTestFailures;
}

GraphQLCache getTestCache() => TestCache();
