import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/location_config.dart';
import '../theme/alfred_colors.dart';

class LocationMapPreview extends StatefulWidget {
  const LocationMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.width = 240,
    this.height = 140,
    this.interactive = false,
    this.zoom = LocationConfig.mapZoom,
  });

  final double latitude;
  final double longitude;
  final double width;
  final double height;
  final bool interactive;
  final double zoom;

  @override
  State<LocationMapPreview> createState() => _LocationMapPreviewState();
}

class _LocationMapPreviewState extends State<LocationMapPreview> {
  final _mapController = MapController();

  @override
  void didUpdateWidget(covariant LocationMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _mapController.move(
        LatLng(widget.latitude, widget.longitude),
        widget.zoom,
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.latitude, widget.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: IgnorePointer(
          ignoring: !widget.interactive,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: widget.zoom,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: LocationConfig.osmTileUrlTemplate,
                userAgentPackageName: 'com.alfred.client',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 36,
                    height: 36,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: AlfredColors.unreadBadge,
                      size: 36,
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(LocationConfig.osmAttribution),
                ],
                alignment: AttributionAlignment.bottomRight,
                showFlutterMapAttribution: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
