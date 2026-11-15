import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows errors at the bottom of any screen. Set on MaterialApp in main.dart.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Turns a technical error into a short message the user can read.
String friendlyError(Object error) {
  if (error is PostgrestException) {
    return error.message.isNotEmpty ? error.message : 'Database error';
  }
  if (error is StorageException) {
    return 'Upload failed: ${error.message}';
  }
  if (error is SocketException) {
    return 'No internet connection. Check your network and try again.';
  }
  if (error is TimeoutException) {
    return 'The request timed out. Please try again.';
  }
  if (error is StateError) {
    return error.message;
  }
  return error.toString();
}

/// Shows [error] to the user and logs it. [where] names the action that
/// failed (for example "Load posts"), so bug reports are easy to match.
void showAppError(Object error, {String? where}) {
  final message = friendlyError(error);
  final label = where == null ? message : '$where: $message';
  debugPrint('[app error] ${where ?? ''} $error');
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(label),
      duration: const Duration(seconds: 5),
    ));
}




