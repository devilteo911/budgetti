import 'dart:async';
import 'dart:io';

import 'package:budgetti/core/error_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('transport failures are network, whatever their type', () {
    expect(classifyError(const SocketException('no route')), ErrorKind.network);
    expect(classifyError(const HttpException('bad')), ErrorKind.network);
    expect(classifyError(TimeoutException('slow')), ErrorKind.network);
  });

  test('PocketBase status 0 means unreachable, not a server answer', () {
    expect(classifyError(ClientException(statusCode: 0)), ErrorKind.network);
    expect(classifyError(ClientException(statusCode: 403)), ErrorKind.server);
    expect(classifyError(ClientException(statusCode: 500)), ErrorKind.server);
  });

  test('anything else is a bug, not something the user can fix', () {
    expect(classifyError(StateError('boom')), ErrorKind.unexpected);
    expect(classifyError(Exception('nope')), ErrorKind.unexpected);
  });
}
