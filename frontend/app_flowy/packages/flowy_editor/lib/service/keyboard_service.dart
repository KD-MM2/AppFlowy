import 'package:flutter/services.dart';

import '../editor_state.dart';
import 'package:flutter/material.dart';

typedef FlowyKeyEventHandler = KeyEventResult Function(
  EditorState editorState,
  RawKeyEvent event,
);

/// Process keyboard events
class FlowyKeyboard extends StatefulWidget {
  const FlowyKeyboard({
    Key? key,
    required this.handlers,
    required this.editorState,
    required this.child,
  }) : super(key: key);

  final EditorState editorState;
  final Widget child;
  final List<FlowyKeyEventHandler> handlers;

  @override
  State<FlowyKeyboard> createState() => _FlowyKeyboardState();
}

class _FlowyKeyboardState extends State<FlowyKeyboard> {
  final FocusNode focusNode = FocusNode(debugLabel: 'flowy_keyboard_service');

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKey: _onKey,
      child: widget.child,
    );
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    debugPrint('on keyboard event $event');

    if (event is! RawKeyDownEvent) {
      return KeyEventResult.ignored;
    }

    for (final handler in widget.handlers) {
      // debugPrint('handle keyboard event $event by $handler');

      KeyEventResult result = handler(widget.editorState, event);

      switch (result) {
        case KeyEventResult.handled:
          return KeyEventResult.handled;
        case KeyEventResult.skipRemainingHandlers:
          return KeyEventResult.skipRemainingHandlers;
        case KeyEventResult.ignored:
          continue;
      }
    }

    return KeyEventResult.ignored;
  }
}
