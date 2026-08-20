import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:budgetti/core/l10n.dart';

/// The only three things a user can act on: retry the connection, look at the
/// server, or report a bug.
enum ErrorKind { network, server, unexpected }

/// Which of the three a caught error is.
///
/// PocketBase reports an unreachable host as a [ClientException] with status 0,
/// so "the server said no" and "there was no server" arrive as the same type.
ErrorKind classifyError(Object error) {
  if (error is SocketException ||
      error is HttpException ||
      error is TimeoutException) {
    return ErrorKind.network;
  }
  if (error is ClientException) {
    return error.statusCode == 0 ? ErrorKind.network : ErrorKind.server;
  }
  return ErrorKind.unexpected;
}

/// Short, safe detail text for a caught error — the `{error}` slot of a
/// "<what failed>: {error}" message.
///
/// `'$e'` is developer text, not user text: [ClientException] prints the
/// request URL and the entire response body, Drift prints the failing SQL. It
/// was reaching ~15 snackbars and error panes verbatim. The user gets the one
/// thing they can act on; the full object goes to the log.
String errorText(BuildContext context, Object error, [StackTrace? stack]) {
  debugPrint('budgetti error: $error');
  if (stack != null) debugPrint('$stack');

  final l10n = context.l10n;
  return switch (classifyError(error)) {
    ErrorKind.network => l10n.errNetwork,
    ErrorKind.server => l10n.errServer((error as ClientException).statusCode),
    ErrorKind.unexpected => l10n.errUnexpected,
  };
}
