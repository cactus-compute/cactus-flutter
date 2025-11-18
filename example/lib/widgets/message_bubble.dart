import 'package:flutter/material.dart';

class AppMessage {
  final String text;
  final bool isUser;
  final List<String>? sources;
  
  AppMessage({
    required this.text,
    required this.isUser,
    this.sources,
  });
}

class MessageBubble extends StatelessWidget {
  final AppMessage message;
  
  const MessageBubble({
    super.key,
    required this.message,
  });
  
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}