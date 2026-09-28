import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

typedef IdentityExchange = Future<Uint8List> Function(Uint8List request);

String identityHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
Uint8List identityBytes(String hex) {
  if (!RegExp(r'^(?:[0-9a-f]{2})+$').hasMatch(hex))
    throw FormatException('Invalid identity encoding');
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16)
  ]);
}

String identityUuid(List<int> bytes) {
  final h = identityHex(bytes);
  if (h.length != 32) throw FormatException('Invalid device ID');
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

// PSA produces IEEE-P1363 r||s; Nexus verifies ASN.1 DER ECDSA signatures.
Uint8List identitySignatureDer(List<int> raw) {
  if (raw.length != 64) throw FormatException('Invalid signature');
  List<int> integer(List<int> v) {
    while (v.length > 1 && v.first == 0) {
      v = v.sublist(1);
    }
    if (v.first >= 128) v = [0, ...v];
    return [2, v.length, ...v];
  }

  final body = [...integer(raw.sublist(0, 32)), ...integer(raw.sublist(32))];
  return Uint8List.fromList([0x30, body.length, ...body]);
}

class NecklaceIdentity {
  NecklaceIdentity(this.exchange);
  final IdentityExchange exchange;
  Future<String?> inspect() async {
    final value = await exchange(Uint8List.fromList([1]));
    if (value.length != 82)
      throw StateError('Necklace identity response is invalid');
    if (value.take(16).every((b) => b == 0)) return null;
    return identityUuid(value.sublist(0, 16));
  }

  Future<void> provision(Map<String, dynamic> setup) async {
    if (setup['device_type'] != 'necklace')
      throw StateError('Wrong device type');
    final id =
        identityBytes((setup['device_id'] as String).replaceAll('-', ''));
    final secret = identityBytes(setup['pairing_secret'] as String);
    if (id.length != 16 || secret.length != 32)
      throw FormatException('Invalid pairing setup');
    final value = await exchange(Uint8List.fromList([2, ...id, ...secret]));
    if (value.length != 82 ||
        identityUuid(value.sublist(0, 16)) != setup['device_id'])
      throw StateError('Pairing identity mismatch');
  }
}

class NecklaceDeviceAuth {
  NecklaceDeviceAuth(
      {required this.baseUrl,
      required this.deviceId,
      required this.exchange,
      required this.isCurrent,
      http.Client? client})
      : _client = client ?? http.Client();
  final String baseUrl, deviceId;
  final IdentityExchange exchange;
  final bool Function() isCurrent;
  final http.Client _client;
  bool _closed = false;
  String? _token;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);
  Future<Map<String, String>>? _pending;
  void _check() {
    if (_closed || !isCurrent()) throw StateError('Device session changed');
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> data) async {
    _check();
    final response = await _client
        .post(Uri.parse('$baseUrl/v1/devices/$path'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));
    _check();
    if (response.statusCode != 200)
      throw StateError('Device authentication failed');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, String>> headers(bool forceRefresh) {
    _check();
    if (!forceRefresh && _token != null && DateTime.now().isBefore(_expires))
      return Future.value({'authorization': 'Bearer $_token'});
    return _pending ??= _authenticate().whenComplete(() => _pending = null);
  }

  Future<Map<String, String>> _authenticate() async {
    if (await NecklaceIdentity(exchange).inspect() != deviceId)
      throw StateError('Connected Necklace does not match enrollment');
    _check();
    final challenge = await _post('challenge', {'device_id': deviceId});
    final nonce = identityBytes(challenge['nonce'] as String);
    if (nonce.length != 32) throw StateError('Invalid challenge');
    final proof = await exchange(Uint8List.fromList([3, ...nonce]));
    _check();
    if (proof.length != 130 && proof.length != 162)
      throw StateError('Invalid device proof');
    final pending = proof[129] == 1;
    if ((pending && proof.length != 162) || (!pending && proof.length != 130))
      throw StateError('Invalid pairing proof');
    final result = await _post('token', {
      'device_id': deviceId,
      'nonce': challenge['nonce'],
      'public_key': identityHex(proof.sublist(0, 65)),
      'signature': identityHex(identitySignatureDer(proof.sublist(65, 129))),
      if (pending) 'pairing_secret': identityHex(proof.sublist(130)),
    });
    final token = result['access_token'];
    if (token is! String || !RegExp(r'^nd1_[0-9a-f]{64}$').hasMatch(token))
      throw StateError('Invalid access token');
    // If this confirmation is lost, retrying the same proof/key remains safe.
    if (pending) await exchange(Uint8List.fromList([4]));
    _check();
    _token = token;
    _expires = DateTime.now()
        .add(Duration(seconds: (result['expires_in'] as int) - 60));
    return {'authorization': 'Bearer $token'};
  }

  void close() {
    _closed = true;
    _token = null;
    _client.close();
  }
}
