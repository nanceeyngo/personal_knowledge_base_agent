import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/message.dart';
import 'source_card.dart';
import 'typing_indicator.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return message.isUser
        ? _UserBubble(message: message)
        : _AssistantBubble(message: message);
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(
            left: 56, right: 16, top: 4, bottom: 4),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Text(
          message.content,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
            left: 16, right: 56, top: 4, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 4, right: 8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 16, color: cs.primary),
                ),
                // Bubble
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: onSurface.withOpacity(0.06),
                      ),
                    ),
                    child: message.isStreaming &&
                        message.content.isEmpty
                        ? const TypingIndicator()
                        : MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                            color: onSurface,
                            fontSize: 15,
                            height: 1.5),
                        code: TextStyle(
                          backgroundColor:
                          onSurface.withOpacity(0.08),
                          fontFamily: 'monospace',
                          color: cs.secondary,
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: onSurface.withOpacity(0.05),
                          borderRadius:
                          BorderRadius.circular(8),
                        ),
                        blockquote: TextStyle(
                            color: onSurface.withOpacity(0.7)),
                        h1: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.w700),
                        h2: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.w600),
                        h3: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.w600),
                        listBullet:
                        TextStyle(color: onSurface),
                        strong: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.w700),
                        em: TextStyle(
                            color: onSurface,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Sources
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sources (${message.sources.length})',
                      style: TextStyle(
                          color: onSurface.withOpacity(0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: message.sources.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                        itemBuilder: (context, i) =>
                            SourceCard(source: message.sources[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
