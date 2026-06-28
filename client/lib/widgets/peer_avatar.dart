import 'package:flutter/material.dart';

import '../models/chat_peer.dart';
import '../utils/avatar_color.dart';

class PeerAvatar extends StatelessWidget {
  const PeerAvatar({
    super.key,
    required this.peer,
    this.radius = 26,
    this.fontSize = 18,
  });

  final ChatPeer peer;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: peer.resolvedAvatarColor,
      backgroundImage:
          peer.avatarUrl != null ? NetworkImage(peer.avatarUrl!) : null,
      child: peer.avatarUrl == null
          ? Text(
              avatarInitial(peer.displayName),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
              ),
            )
          : null,
    );
  }
}
