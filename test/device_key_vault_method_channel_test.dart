import 'package:device_key_vault/device_key_vault.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('device_key_vault');
  final calls = <MethodCall>[];
  Object? Function(MethodCall) answer = (_) => null;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final a = answer(call);
      if (a is PlatformException) throw a;
      return a;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const vault = DeviceKeyVault();

  group('availability', () {
    test('ready, with the kind of sensor', () async {
      answer = (_) => {'ready': true, 'kind': 'face', 'reason': null};
      final a = await vault.availability();
      expect(a.isReady, isTrue);
      expect(a.kind, BiometricKind.face);
    });

    test('not enrolled is a reason, not an exception', () async {
      answer = (_) => {'ready': false, 'kind': null, 'reason': 'not_enrolled'};
      final a = await vault.availability();
      expect(a.isReady, isFalse);
      expect(a.reason, VaultUnavailableReason.notEnrolled);
    });

    test('biometrics refused to the app is a reason of its own', () async {
      answer = (_) => {'ready': false, 'kind': null, 'reason': 'not_allowed'};
      final a = await vault.availability();
      expect(a.isReady, isFalse);
      expect(a.reason, VaultUnavailableReason.notAllowed);
    });

    test('an unknown kind or reason degrades, never crashes', () async {
      answer = (_) => {'ready': true, 'kind': 'retina-9000', 'reason': null};
      expect((await vault.availability()).kind, BiometricKind.other);
      answer = (_) => {'ready': false, 'kind': null, 'reason': 'solar-flare'};
      expect((await vault.availability()).reason, VaultUnavailableReason.noHardware);
    });
  });

  group('store', () {
    test('sends the secret and the prompt, and succeeds on null', () async {
      answer = (_) => null;
      final r = await vault.store('s3cret', prompt: 'Turn on Face ID');
      expect(r, isA<VaultSuccess<void>>());
      expect(calls.single.method, 'store');
      expect(calls.single.arguments, {'secret': 's3cret', 'prompt': 'Turn on Face ID'});
    });

    test('a platform failure comes back as a typed error', () async {
      answer = (_) => PlatformException(code: 'cancelled');
      final r = await vault.store('s3cret', prompt: 'p');
      expect((r as VaultError<void>).failure, VaultFailure.cancelled);
    });

    test('an empty prompt fails without calling the platform', () async {
      answer = (_) => null;
      final r = (await vault.store('s3cret', prompt: '')) as VaultError<void>;
      expect(r.failure, VaultFailure.failed);
      expect(r.message, 'prompt must not be empty');
      expect(calls, isEmpty);
    });
  });

  group('unlock', () {
    test('a blank prompt fails without calling the platform', () async {
      answer = (_) => 's3cret';
      final r = (await vault.unlock(prompt: ' \n')) as VaultError<String>;
      expect(r.failure, VaultFailure.failed);
      expect(r.message, 'prompt must not be empty');
      expect(calls, isEmpty);
    });

    test('returns the secret', () async {
      answer = (_) => 's3cret';
      final r = await vault.unlock(prompt: 'Sign in');
      expect((r as VaultSuccess<String>).value, 's3cret');
      expect(calls.single.arguments, {'prompt': 'Sign in'});
    });

    test('every channel code maps to its failure, and anything else is failed', () async {
      const codes = {
        'cancelled': VaultFailure.cancelled,
        'invalidated': VaultFailure.invalidated,
        'not_found': VaultFailure.notFound,
        'locked_out': VaultFailure.lockedOut,
        'unavailable': VaultFailure.unavailable,
        'failed': VaultFailure.failed,
        'something-new': VaultFailure.failed,
      };
      for (final e in codes.entries) {
        answer = (_) => PlatformException(code: e.key, message: 'm');
        final r = await vault.unlock(prompt: 'p');
        expect((r as VaultError<String>).failure, e.value, reason: e.key);
      }
    });

    test('a null secret is a failure, not an empty string', () async {
      answer = (_) => null;
      final r = await vault.unlock(prompt: 'p');
      expect((r as VaultError<String>).failure, VaultFailure.failed);
    });
  });

  test('clear calls the platform', () async {
    answer = (_) => null;
    await vault.clear();
    expect(calls.single.method, 'clear');
  });
}
