import 'package:graphql/src/core/_base_options.dart';
import 'package:meta/meta.dart';

import 'package:gql/ast.dart';
import 'package:gql_exec/gql_exec.dart';

import 'package:graphql/client.dart';
import 'package:graphql/src/core/policies.dart';

/// Query options.
class QueryOptions extends BaseOptions {
  QueryOptions({
    @required DocumentNode document,
    String operationName,
    Map<String, dynamic> variables = const {},
    FetchPolicy fetchPolicy,
    ErrorPolicy errorPolicy,
    Object optimisticResult,
    this.pollInterval,
    Context context,
  }) : super(
          fetchPolicy: fetchPolicy,
          errorPolicy: errorPolicy,
          document: document,
          operationName: operationName,
          variables: variables,
          context: context,
          optimisticResult: optimisticResult,
        );

  /// The time interval (in milliseconds) on which this query should be
  /// re-fetched from the server.
  int pollInterval;

  @override
  List<Object> get properties => [...super.properties, pollInterval];

  WatchQueryOptions asWatchQueryOptions({bool fetchResults = true}) =>
      WatchQueryOptions(
        document: document,
        variables: variables,
        fetchPolicy: fetchPolicy,
        errorPolicy: errorPolicy,
        pollInterval: pollInterval,
        fetchResults: fetchResults ?? true,
        context: context,
        optimisticResult: optimisticResult,
      );
}

class SubscriptionOptions extends BaseOptions {
  SubscriptionOptions({
    @required DocumentNode document,
    String operationName,
    Map<String, dynamic> variables = const {},
    FetchPolicy fetchPolicy,
    ErrorPolicy errorPolicy,
    Object optimisticResult,
    Context context,
  }) : super(
          fetchPolicy: fetchPolicy,
          errorPolicy: errorPolicy,
          document: document,
          operationName: operationName,
          variables: variables,
          context: context,
          optimisticResult: optimisticResult,
        );

  /// An optimistic first result to eagerly add to the subscription stream
  Object optimisticResult;
}

class WatchQueryOptions extends QueryOptions {
  WatchQueryOptions({
    @required DocumentNode document,
    String operationName,
    Map<String, dynamic> variables = const {},
    FetchPolicy fetchPolicy,
    ErrorPolicy errorPolicy,
    Object optimisticResult,
    int pollInterval,
    this.fetchResults = false,
    bool eagerlyFetchResults,
    Context context,
  })  : eagerlyFetchResults = eagerlyFetchResults ?? fetchResults,
        super(
          document: document,
          operationName: operationName,
          variables: variables,
          fetchPolicy: fetchPolicy,
          errorPolicy: errorPolicy,
          pollInterval: pollInterval,
          context: context,
          optimisticResult: optimisticResult,
        );

  /// Whether or not to fetch results
  bool fetchResults;

  /// Whether to [fetchResults] immediately on instantiation.
  /// Defaults to [fetchResults].
  bool eagerlyFetchResults;

  @override
  List<Object> get properties =>
      [...super.properties, fetchResults, eagerlyFetchResults];

  WatchQueryOptions copy() => WatchQueryOptions(
        document: document,
        operationName: operationName,
        variables: variables,
        fetchPolicy: fetchPolicy,
        errorPolicy: errorPolicy,
        optimisticResult: optimisticResult,
        pollInterval: pollInterval,
        fetchResults: fetchResults,
        eagerlyFetchResults: eagerlyFetchResults,
        context: context,
      );
}

/// options for fetchMore operations
class FetchMoreOptions {
  FetchMoreOptions({
    this.document,
    this.variables = const {},
    @required this.updateQuery,
  }) : assert(updateQuery != null);

  DocumentNode document;

  Map<String, dynamic> variables;

  /// Strategy for merging the fetchMore result data
  /// with the result data already in the cache
  UpdateQuery updateQuery;
}

/// merge fetchMore result data with earlier result data
typedef dynamic UpdateQuery(
  dynamic previousResultData,
  dynamic fetchMoreResultData,
);

extension WithType on Request {
  OperationType get type {
    final definitions = operation.document.definitions
        .whereType<OperationDefinitionNode>()
        .toList();
    if (operation.operationName != null) {
      definitions.removeWhere(
        (node) => node.name.value != operation.operationName,
      );
    }
    // TODO differentiate error types, add exception
    assert(definitions.length == 1);
    return definitions.first.type;
  }

  bool get isQuery => type == OperationType.query;
  bool get isMutation => type == OperationType.mutation;
  bool get isSubscription => type == OperationType.subscription;
}
