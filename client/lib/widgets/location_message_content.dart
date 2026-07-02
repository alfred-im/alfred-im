import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/location_config.dart';
import '../theme/alfred_colors.dart';

const double _locationMapWidth = 240;
const double _locationMapHeight = 140;

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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                LocationConfig.staticMapUrl(latitude, longitude),
                width: _locationMapWidth,
                height: _locationMapHeight,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    width: _locationMapWidth,
                    height: _locationMapHeight,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: _locationMapWidth,
                    height: _locationMapHeight,
                    color: AlfredColors.border,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AlfredColors.unreadBadge,
                      size: 40,
                    ),
                  );
                },
              ),
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
