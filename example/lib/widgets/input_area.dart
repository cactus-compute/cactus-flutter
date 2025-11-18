import 'package:flutter/material.dart';

class InputArea extends StatelessWidget {
  final bool isAddingDocument;
  final bool isProcessing;
  final VoidCallback onAddDocument;
  final VoidCallback onSend;
  final TextEditingController messageController;
  final bool canSend;
  
  const InputArea({
    super.key,
    required this.isAddingDocument,
    required this.isProcessing,
    required this.onAddDocument,
    required this.onSend,
    required this.messageController,
    required this.canSend,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Add document button
          IconButton(
            onPressed: isAddingDocument ? null : onAddDocument,
            icon: isAddingDocument
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          // Text input
          Expanded(
            child: TextField(
              controller: messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: canSend ? (_) => onSend() : null,
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          IconButton(
            onPressed: canSend && !isProcessing ? onSend : null,
            icon: isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            color: canSend ? Colors.blue : Colors.grey,
          ),
        ],
      ),
    );
  }
}