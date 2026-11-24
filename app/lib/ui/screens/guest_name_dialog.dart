import 'package:flutter/material.dart';

import '../../copy.dart';
import '../widgets/text_dialog_host.dart';

/// Asks for a name when playing outside the Pi Browser.
Future<String?> showGuestNameDialog(BuildContext context) async {
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => TextDialogHost(
      builder: (ctx, controller) => AlertDialog(
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
    ),
  );
  return name;
}
