import 'package:flutter/widgets.dart';

/// Owns a [TextEditingController] for a dialog and disposes it only when the
/// dialog's route is gone, after its closing animation (which still builds
/// the text field) has finished.
class TextDialogHost extends StatefulWidget {
  const TextDialogHost({super.key, this.initial = '', required this.builder});

  final String initial;
  final Widget Function(BuildContext context, TextEditingController controller) builder;

  @override
  State<TextDialogHost> createState() => _TextDialogHostState();
}

class _TextDialogHostState extends State<TextDialogHost> {
  late final controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, controller);
}
