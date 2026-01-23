import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class AddStopScreen extends ConsumerStatefulWidget {
  const AddStopScreen({super.key, required this.roundId});

  final String roundId;

  @override
  ConsumerState<AddStopScreen> createState() => _AddStopScreenState();
}

class _AddStopScreenState extends ConsumerState<AddStopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _phone = TextEditingController();
  final _parcelCount = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    _name.dispose();
    _notes.dispose();
    _phone.dispose();
    _parcelCount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final parcel = int.tryParse(_parcelCount.text.trim());
      await ref.read(roundControllerProvider(widget.roundId).notifier).addStop(
            address: _address.text.trim(),
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            parcelCount: parcel,
          );

      // Refresh route now that stops changed
      await ref
          .read(routeControllerProvider(widget.roundId).notifier)
          .refresh(force: true);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add stop: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add stop')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    hintText: 'House number, street, city, postcode',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Address required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _parcelCount,
                  decoration: const InputDecoration(
                    labelText: 'Parcel count (optional)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save stop'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
