import 'package:flutter/material.dart';

import '../theme/alfred_colors.dart';

/// Logo Alfred: spunta in cerchio (brand legacy).
class AlfredLogo extends StatelessWidget {
  const AlfredLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AlfredColors.textOnDark.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: AlfredColors.textOnDark.withValues(alpha: 0.35)),
      ),
      child: Icon(
        Icons.check_rounded,
        color: AlfredColors.textOnDark,
        size: size * 0.55,
      ),
    );
  }
}
