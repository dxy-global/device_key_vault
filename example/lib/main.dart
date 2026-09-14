import 'package:device_key_vault/device_key_vault.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Bench()));

/// Four buttons and a log. Everything a person needs to check the plugin on a
/// real phone: enrol or remove a face or finger in Settings between presses.
class Bench extends StatefulWidget {
  const Bench({super.key});

  @override
  State<Bench> createState() => _BenchState();
}

class _BenchState extends State<Bench> {
  static const vault = DeviceKeyVault();
  final _log = <String>[];

  void _add(String line) => setState(() => _log.insert(0, line));

  String _describe(VaultResult<Object?> r) => switch (r) {
        VaultSuccess(:final value) => 'success ${value ?? ''}',
        VaultError(:final failure, :final message) => 'error ${failure.name} ${message ?? ''}',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('device_key_vault')),
        body: Column(children: [
          Wrap(spacing: 8, children: [
            FilledButton(
              key: const Key('dkv-availability'),
              onPressed: () async {
                final a = await vault.availability();
                _add(a.isReady ? 'ready ${a.kind!.name}' : 'unavailable ${a.reason!.name}');
              },
              child: const Text('Availability'),
            ),
            FilledButton(
              key: const Key('dkv-store'),
              onPressed: () async => _add('store ${_describe(await vault.store(
                  'secret-${DateTime.now().millisecondsSinceEpoch}', prompt: 'Store a test secret'))}'),
              child: const Text('Store'),
            ),
            FilledButton(
              key: const Key('dkv-unlock'),
              onPressed: () async => _add('unlock ${_describe(await vault.unlock(prompt: 'Unlock the test secret'))}'),
              child: const Text('Unlock'),
            ),
            OutlinedButton(
              key: const Key('dkv-clear'),
              onPressed: () async {
                await vault.clear();
                _add('cleared');
              },
              child: const Text('Clear'),
            ),
          ]),
          const Divider(),
          Expanded(child: ListView(children: [for (final l in _log) ListTile(dense: true, title: Text(l))])),
        ]),
      );
}
