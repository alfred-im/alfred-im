import 'package:flutter/material.dart';

import '../theme/alfred_colors.dart';

/// Barra input messaggi — solo UI, nessun invio reale.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AlfredColors.surface,
        border: Border(top: BorderSide(color: AlfredColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.add_circle_outline, color: AlfredColors.textSecondary),
            tooltip: 'Allega (mock)',
          ),
          Expanded(
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Scrivi un messaggio…',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AlfredColors.panel,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: AlfredColors.charcoal,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: null,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send_rounded, color: AlfredColors.textOnDark, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
