import 'package:flutter/material.dart';

import '../../copy.dart';
import '../theme.dart';
import '../widgets/text_dialog_host.dart';

/// Asks for a nickname and hands it to [save], which returns null on success
/// or a message to show (e.g. "That name is taken."). Returns whether a
/// nickname was saved. With [required] the dialog cannot be dismissed.
Future<bool> showNicknameDialog(
  BuildContext context, {
  required Future<String?> Function(String nickname) save,
  String initial = '',
  bool required = false,
}) async {
  String? error;
  var busy = false;
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: !required,
    builder: (ctx) => PopScope(
      canPop: !required,
      child: TextDialogHost(
        initial: initial,
        builder: (ctx, controller) => StatefulBuilder(builder: (ctx, setState) {
          Future<void> submit() async {
            final name = controller.text.trim();
            if (name.isEmpty || busy) return;
            setState(() {
              busy = true;
              error = null;
            });
            final problem = await save(name);
            if (!ctx.mounted) return;
            if (problem == null) {
              Navigator.pop(ctx, true);
            } else {
              setState(() {
                busy = false;
                error = problem;
              });
            }
          }

          return AlertDialog(
            title: const Text(Copy.nicknameTitle),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(Copy.nicknameBody, style: TextStyle(fontSize: 13)),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 16,
                enabled: !busy,
                decoration: InputDecoration(hintText: Copy.nicknameHint, errorText: error),
                onChanged: (_) => setState(() => error = null),
                onSubmitted: (_) => submit(),
              ),
              const Text(Copy.nicknameRules, style: TextStyles.small),
            ]),
            actions: [
              if (!required)
                TextButton(
                    onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text(Copy.nicknameCancel)),
              FilledButton(
                onPressed: busy || controller.text.trim().isEmpty ? null : submit,
                child: const Text(Copy.nicknameSave),
              ),
            ],
          );
        }),
      ),
    ),
  );
  return saved ?? false;
}
