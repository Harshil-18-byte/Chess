import 'package:flutter/material.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, Object error, StackTrace stackTrace) fallbackBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    required this.fallbackBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _error = null;
    _stackTrace = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallbackBuilder(context, _error!, _stackTrace!);
    }
    
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      // In a real implementation we would want to set state, but ErrorWidget.builder 
      // doesn't let us easily rebuild the parent. 
      // Using a custom Builder allows us to catch it within the render tree if we use a Builder.
      // For now, if a FlutterError happens in the child, we capture it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _error == null) {
          setState(() {
            _error = errorDetails.exception;
            _stackTrace = errorDetails.stack;
          });
        }
      });
      return const SizedBox.shrink(); // Hide the red screen of death temporarily
    };

    return widget.child;
  }
}
