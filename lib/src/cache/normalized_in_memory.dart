import 'package:meta/meta.dart';
import 'package:graphql_flutter/src/utilities/traverse.dart';
import 'package:graphql_flutter/src/cache/in_memory.dart';

import './lazy_cache_map.dart';

typedef DataIdFromObject = String Function(Object node);

class NormalizationException implements Exception {
  NormalizationException(this.cause, this.overflowError, this.value);

  StackOverflowError overflowError;
  String cause;
  Object value;

  String get message => cause;
}

typedef Normalizer = List<String> Function(Object node);

class NormalizedInMemoryCache extends InMemoryCache {
  NormalizedInMemoryCache({
    @required this.dataIdFromObject,
    this.prefix = '@cache/reference',
  });

  bool _isReference(Object node) =>
      node is List && node.length == 2 && node[0] == prefix;

  DataIdFromObject dataIdFromObject;
  String prefix;

  Dereference get _dereference {
    final Map<String, Object> seen = <String, Object>{};
    Object dereference(Object node) {
      if (node is List && _isReference(node)) {
        final String key = node[1] as String;
        if (seen.containsKey(key)) {
          return seen[key];
        }
        return read(key, dereference: dereference);
      }

      return null;
    }

    return dereference;
  }

  LazyMap lazilyDenormalized(
    Map<String, Object> data, {
    Dereference dereference,
  }) {
    return LazyMap(
      data: data,
      dereference: dereference ?? _dereference,
    );
  }

  Object _denormalizingDereference(Object node) {
    if (node is List && _isReference(node)) {
      return denormalizedRead(node[1] as String);
    }

    return null;
  }

  // TODO ideally cyclical references would be noticed and replaced with null or something
  /// eagerly dereferences all cache references.
  /// *WARNING* if your system allows cyclical references, this will break
  dynamic denormalizedRead(String key) {
    try {
      return traverse(super.read(key), _denormalizingDereference);
    } catch (error) {
      if (error is StackOverflowError) {
        throw NormalizationException(
          '''
          Denormalization failed for $key this is likely caused by a circular reference.
          Please ensure dataIdFromObject returns a unique identifier for all possible entities in your system
          ''',
          error,
          key,
        );
      }
    }
  }

  /*
    Dereferences object references,
    replacing them with cached instances
  */
  @override
  dynamic read(
    String key, {
    Dereference dereference,
  }) {
    final Object value = super.read(key);
    return value is Map<String, Object>
        ? lazilyDenormalized(value, dereference: dereference ?? _dereference)
        : value;
  }

  Normalizer _normalizerFor(Map<String, Object> into) {
    List<String> normalizer(Object node) {
      final String dataId = dataIdFromObject(node);
      if (dataId != null) {
        writeInto(dataId, node, into, normalizer);
        return <String>[prefix, dataId];
      }
      return null;
    }

    return normalizer;
  }

  List<String> _normalize(Object node) {
    final String dataId = dataIdFromObject(node);

    if (dataId != null) {
      writeInto(dataId, node, data, _normalize);
      return <String>[prefix, dataId];
    }

    return null;
  }

  /// Writes included objects to provided Map,
  /// replacing discernable entities with references
  void writeInto(
    String key,
    Object value,
    Map<String, Object> into, [
    Normalizer normalizer,
  ]) {
    // writing non-map data to the store is allowed
    final Object normalized = value is Map<String, Object>
        ? traverseValues(value, normalizer ?? _normalizerFor(into))
        : value;
    into[key] = normalized;
  }

  /// Writes included objects to store,
  /// replacing discernable entities with references
  @override
  void write(String key, Object value) {
    writeInto(key, value, data, _normalize);
  }
}

String typenameDataIdFromObject(Object object) {
  if (object is Map<String, Object> &&
      object.containsKey('__typename') &&
      object.containsKey('id')) {
    return "${object['__typename']}/${object['id']}";
  }

  return null;
}
