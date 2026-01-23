import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/co2_estimator.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          final controller = ref.read(settingsControllerProvider.notifier);

          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Eco mode'),
                subtitle: const Text(
                  'Bias toward eco-friendly routes (also enables avoid highways).',
                ),
                value: settings.ecoMode,
                onChanged: controller.setEcoMode,
              ),
              SwitchListTile(
                title: const Text('Avoid tolls'),
                value: settings.avoidTolls,
                onChanged: controller.setAvoidTolls,
              ),
              SwitchListTile(
                title: const Text('Avoid highways'),
                value: settings.avoidHighways,
                onChanged: controller.setAvoidHighways,
              ),
              const Divider(),
              ListTile(
                title: const Text('Vehicle type (for CO₂ estimate)'),
                subtitle: Text(settings.vehicleType.name.toUpperCase()),
              ),
              for (final vt in VehicleType.values)
                RadioListTile<VehicleType>(
                  title: Text(vt.name.toUpperCase()),
                  value: vt,
                  groupValue: settings.vehicleType,
                  onChanged: (v) {
                    if (v != null) controller.setVehicleType(v);
                  },
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'CO₂ estimate factors (kg/km) – optional overrides',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final vt in VehicleType.values) _FactorTile(vehicleType: vt),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _FactorTile extends ConsumerWidget {
  const _FactorTile({required this.vehicleType});

  final VehicleType vehicleType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).value;
    if (settings == null) return const SizedBox.shrink();

    final controller = ref.read(settingsControllerProvider.notifier);

    final defaultFactor = Co2Estimator.defaultKgPerKm[vehicleType]!;
    final override = settings.co2KgPerKmOverrides[vehicleType.name];

    return ListTile(
      title: Text(vehicleType.name.toUpperCase()),
      subtitle: Text(
        'Default: ${defaultFactor.toStringAsFixed(3)} kg/km'
        '${override != null ? ' | Override: ${override.toStringAsFixed(3)} kg/km' : ''}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () async {
          final input = TextEditingController(
            text: (override ?? defaultFactor).toString(),
          );

          final val = await showDialog<double?>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Override ${vehicleType.name.toUpperCase()} factor'),
              content: TextField(
                controller: input,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'kg CO₂ per km',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(input.text.trim());
                    Navigator.pop(ctx, parsed);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );

          if (val == null) return;
          await controller.setCo2Override(vehicleType, val);

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved CO₂ factor override.')),
          );
        },
      ),
    );
  }
}
