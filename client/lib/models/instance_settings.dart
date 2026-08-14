// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Branding opzionale dell'istanza (`instance.branding`).
class InstanceBrandingAssets {
  const InstanceBrandingAssets({
    this.logoUrl,
    this.themeColor,
  });

  factory InstanceBrandingAssets.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const InstanceBrandingAssets();
    return InstanceBrandingAssets(
      logoUrl: json['logo_url'] as String?,
      themeColor: json['theme_color'] as String?,
    );
  }

  final String? logoUrl;
  final String? themeColor;
}

/// Link legali opzionali (`instance.legal`).
class InstanceLegalLinks {
  const InstanceLegalLinks({
    this.privacyUrl,
    this.termsUrl,
    this.supportUrl,
  });

  factory InstanceLegalLinks.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const InstanceLegalLinks();
    return InstanceLegalLinks(
      privacyUrl: json['privacy_url'] as String?,
      termsUrl: json['terms_url'] as String?,
      supportUrl: json['support_url'] as String?,
    );
  }

  final String? privacyUrl;
  final String? termsUrl;
  final String? supportUrl;

  bool get hasAny =>
      (privacyUrl?.isNotEmpty ?? false) ||
      (termsUrl?.isNotEmpty ?? false) ||
      (supportUrl?.isNotEmpty ?? false);
}

/// Impostazioni servizio caricate da `instance_config` (non software Alfred).
class InstanceSettings {
  const InstanceSettings({
    required this.displayName,
    required this.imServerId,
    this.branding = const InstanceBrandingAssets(),
    this.legal = const InstanceLegalLinks(),
  });

  factory InstanceSettings.fromBootstrapJson(Map<String, dynamic> raw) {
    String readString(String key, {required String fallback}) {
      final value = raw[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return fallback;
    }

    Map<String, dynamic>? readObject(String key) {
      final value = raw[key];
      if (value is Map<String, dynamic>) return value;
      return null;
    }

    return InstanceSettings(
      displayName: readString('instance.display_name', fallback: 'Messaging'),
      imServerId: readString('instance.im_server_id', fallback: 'localhost'),
      branding: InstanceBrandingAssets.fromJson(
        readObject('instance.branding'),
      ),
      legal: InstanceLegalLinks.fromJson(readObject('instance.legal')),
    );
  }

  final String displayName;
  final String imServerId;
  final InstanceBrandingAssets branding;
  final InstanceLegalLinks legal;
}
