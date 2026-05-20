import 'package:flutter_test/flutter_test.dart';
import 'package:nx_utils/nx_utils.dart';

void main() {
  test('httpBaseFromSocketUrl maps websocket ports to HTTP ports', () {
    expect(httpBaseFromSocketUrl('ws://10.0.0.210:8002'),
        'http://10.0.0.210:8001');
    expect(httpBaseFromSocketUrl('wss://socket.nathikazad.com'),
        'https://nexus.nathikazad.com');
  });
}
