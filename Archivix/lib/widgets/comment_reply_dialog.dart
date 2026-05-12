import 'package:flutter/material.dart';

class CommentReplyDialog extends StatefulWidget {
  const CommentReplyDialog({super.key});

  @override
  State<CommentReplyDialog> createState() => _CommentReplyDialogState();
}

class _CommentReplyDialogState extends State<CommentReplyDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    Navigator.of(context).pop(body);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reply to comment'),
      content: TextField(
        controller: _controller,
        minLines: 3,
        maxLines: 6,
        maxLength: 2000,
        autofocus: true,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          hintText: 'Write your reply...',
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.reply, size: 16),
          label: const Text('Reply'),
        ),
      ],
    );
  }
}
