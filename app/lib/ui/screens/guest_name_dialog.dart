import 'package:flutter/material.dart';

import '../../copy.dart';

/// Asks for a name when playing outside the Pi Browser.
Future<String?> showGuestNameDialog(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text(Copy.guestDialogTitle),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text(Copy.guestDialogBody, style: TextStyle(fontSize: 13)),
        TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: const InputDecoration(hintText: Copy.guestNameHint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text(Copy.guestStart))],
    ),
  );
  controller.dispose();
  return name;
}
