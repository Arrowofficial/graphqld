import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:graphql/client.dart';
import 'package:graphql/internal.dart';

import 'package:graphql_flutter/src/widgets/graphql_provider.dart';
import 'package:connectivity/connectivity.dart';

typedef OnSubscriptionCompleted = void Function();

typedef SubscriptionBuilder<T> = Widget Function({
  bool loading,
  T payload,
  dynamic error,
});

class Subscription<T> extends StatefulWidget {
  const Subscription(
    this.operationName,
    this.query, {
    this.variables = const <String, dynamic>{},
    final Key key,
    @required this.builder,
    this.initial,
    this.onCompleted,
  }) : super(key: key);

  final String operationName;
  final String query;
  final Map<String, dynamic> variables;
  final SubscriptionBuilder<T> builder;
  final OnSubscriptionCompleted onCompleted;
  final T initial;

  @override
  _SubscriptionState<T> createState() => _SubscriptionState<T>();
}

class _SubscriptionState<T> extends State<Subscription<T>> {
  bool _loading = true;
  T _data;
  dynamic _error;
  StreamSubscription<FetchResult> _subscription;

  void _initSubscription() {
    final GraphQLClient client = GraphQLProvider.of(context).value;
    assert(client != null);
    final Operation operation = Operation(
      document: widget.query,
      variables: widget.variables,
      operationName: widget.operationName,
    );

    final Stream<FetchResult> stream = client.subscribe(operation);

    if (_subscription == null) {
      // Set the initial value for the first time.
      if (widget.initial != null) {
        setState(() {
          _loading = true;
          _data = widget.initial;
          _error = null;
        });
      }
    }

    _subscription?.cancel();
    _subscription = stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
    );
  }

  ConnectivityResult _currentConnectivityResult;
  StreamSubscription<ConnectivityResult> _networkSubscription;

  @override
  void initState() {
    debugPrint("INIT!");
    _networkSubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) async {
      // if state change from no internet connection to internet connection
      if (_currentConnectivityResult == ConnectivityResult.none &&
          (result == ConnectivityResult.mobile ||
              result == ConnectivityResult.wifi)) {
        // android connectivitystate cannot be trusted
        // validate with nslookup
        if (Platform.isAndroid) {
          try {
            final nsLookupResult = await InternetAddress.lookup('google.com');
            if (nsLookupResult.isNotEmpty &&
                nsLookupResult[0].rawAddress.isNotEmpty) {
              _initSubscription();
              _currentConnectivityResult = result;
            }
          } on SocketException catch (_) {
            // debugPrint('not connected');
          }
        } else {
          _initSubscription();
          _currentConnectivityResult = result;
        }
      } else {
        _currentConnectivityResult = result;
      }
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initSubscription();
  }

  @override
  void didUpdateWidget(Subscription<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.query != oldWidget.query ||
        widget.operationName != oldWidget.operationName ||
        areDifferentVariables(widget.variables, oldWidget.variables)) {
      _initSubscription();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _networkSubscription?.cancel();
    super.dispose();
  }

  void _onData(final FetchResult message) {
    setState(() {
      _loading = false;
      _data = message.data as T;
      _error = message.errors;
    });
  }

  void _onError(final Object error) {
    setState(() {
      _loading = false;
      _data = null;
      _error = (error is SubscriptionError) ? error.payload : error;
    });
  }

  void _onDone() {
    if (widget.onCompleted != null) {
      widget.onCompleted();
    }
  }

  @override
  Widget build(final BuildContext context) {
    return widget.builder(
      loading: _loading,
      error: _error,
      payload: _data,
    );
  }
}
