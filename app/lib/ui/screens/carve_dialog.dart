import 'package:flutter/material.dart';

import '../../copy.dart';
import '../../payments/carve_service.dart';
import '../theme.dart';
import '../widgets/text_dialog_host.dart';

/// Asks what to carve at [height]; returns the words, or null to cancel.
Future<String?> showCarveDialog(BuildContext context, {required int height, required double price}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => TextDialogHost(
      builder: (ctx, controller) => StatefulBuilder(
        builder: (ctx, setState) {
          final ok = controller.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Text(Copy.carveTitle),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(Copy.carveBody, style: TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Text(Copy.carveAt(height), style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.accent)),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: maxCarvingLength,
                decoration: const InputDecoration(hintText: Copy.carveHint),
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.pop(ctx, v.trim()),
              ),
              const Text(Copy.carveRules, style: TextStyles.small),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(Copy.carveCancel)),
              FilledButton(
                onPressed: ok ? () => Navigator.pop(ctx, controller.text.trim()) : null,
                child: Text(Copy.carveFor(price)),
              ),
            ],
          );
        },
      ),
    ),
  );
  return text;
}
