import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum PinPurpose { appAccess, transfer }

extension PinPurposeRules on PinPurpose {
  int get length => this == PinPurpose.appAccess ? 6 : 4;

  String get storageName =>
      this == PinPurpose.appAccess ? 'app_access' : 'transfer';
}

class PinStatus {
  const PinStatus({required this.configured, required this.failedAttempts});

  final bool configured;
  final int failedAttempts;

  bool get locked => failedAttempts >= PinSecurityService.maxAttempts;
}

class PinVerificationResult extends PinStatus {
  const PinVerificationResult({
    required super.configured,
    required super.failedAttempts,
    required this.matched,
  });

  final bool matched;
}

abstract interface class PinValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecurePinValueStore implements PinValueStore {
  SecurePinValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

@visibleForTesting
class MemoryPinValueStore implements PinValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class PinSecurityService {
  PinSecurityService({PinValueStore? store})
    : _store = store ?? SecurePinValueStore();

  static const maxAttempts = 5;

  final PinValueStore _store;

  Future<PinStatus> status({
    required String accountScope,
    required PinPurpose purpose,
  }) async {
    final pin = await _store.read(_pinKey(accountScope, purpose));
    final failedAttempts = _parseAttempts(
      await _store.read(_attemptsKey(accountScope, purpose)),
    );
    return PinStatus(configured: pin != null, failedAttempts: failedAttempts);
  }

  Future<void> setPin({
    required String accountScope,
    required PinPurpose purpose,
    required String pin,
  }) async {
    if (!_isValidPin(pin, purpose.length)) {
      throw ArgumentError.value(pin, 'pin', 'PIN format is invalid.');
    }
    await _store.write(_pinKey(accountScope, purpose), pin);
    await _store.delete(_attemptsKey(accountScope, purpose));
  }

  Future<PinVerificationResult> verify({
    required String accountScope,
    required PinPurpose purpose,
    required String pin,
  }) async {
    final pinKey = _pinKey(accountScope, purpose);
    final attemptsKey = _attemptsKey(accountScope, purpose);
    final savedPin = await _store.read(pinKey);
    var failedAttempts = _parseAttempts(await _store.read(attemptsKey));
    if (savedPin == null) {
      return PinVerificationResult(
        configured: false,
        failedAttempts: failedAttempts,
        matched: false,
      );
    }
    if (failedAttempts >= maxAttempts) {
      return PinVerificationResult(
        configured: true,
        failedAttempts: maxAttempts,
        matched: false,
      );
    }
    if (savedPin == pin) {
      await _store.delete(attemptsKey);
      return const PinVerificationResult(
        configured: true,
        failedAttempts: 0,
        matched: true,
      );
    }
    failedAttempts = (failedAttempts + 1).clamp(0, maxAttempts);
    await _store.write(attemptsKey, '$failedAttempts');
    return PinVerificationResult(
      configured: true,
      failedAttempts: failedAttempts,
      matched: false,
    );
  }

  Future<void> clear({
    required String accountScope,
    required PinPurpose purpose,
  }) async {
    await _store.delete(_pinKey(accountScope, purpose));
    await _store.delete(_attemptsKey(accountScope, purpose));
  }

  String _pinKey(String scope, PinPurpose purpose) =>
      'nh_allone_pin_v1_${_encodedScope(scope)}_${purpose.storageName}';

  String _attemptsKey(String scope, PinPurpose purpose) =>
      '${_pinKey(scope, purpose)}_failed_attempts';

  String _encodedScope(String scope) =>
      base64Url.encode(utf8.encode(scope)).replaceAll('=', '');

  int _parseAttempts(String? value) =>
      (int.tryParse(value ?? '') ?? 0).clamp(0, maxAttempts);

  bool _isValidPin(String pin, int length) =>
      pin.length == length && RegExp(r'^\d+$').hasMatch(pin);
}
