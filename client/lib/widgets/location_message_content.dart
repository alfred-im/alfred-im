import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/location_config.dart';
import '../theme/alfred_colors.dart';
import 'location_map_preview.dart';

class LocationMessageContent extends StatelessWidget {
  const LocationMessageContent({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  Future<void> _openInMaps() async {
    final uri = Uri.parse(LocationConfig.openInMapsUrl(latitude, longitude));
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Impossibile aprire la mappa');
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = LocationConfig.formatCoordinates(latitude, longitude);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openInMaps(),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocationMapPreview(
              latitude: latitude,
              longitude: longitude,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AlfredColors.unreadBadge,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    coordinates,
                    style: const TextStyle(
                      color: AlfredColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Tocca per aprire la mappa',
              style: TextStyle(
                color: AlfredColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
