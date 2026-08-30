// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Schema editabile `instance_config` — SSOT allineato a [InstanceSettings].
///
/// Chiavi top-level in DB (solo queste quattro):
/// - `instance.display_name` (stringa JSON)
/// - `instance.im_server_id` (stringa JSON)
/// - `instance.branding` (oggetto: logo_url, favicon_url, short_name, …)
/// - `instance.legal` (oggetto: privacy_url, terms_url, support_url)
enum InstanceConfigFieldKind { text, url, color, asset }

class InstanceConfigFieldDef {
  const InstanceConfigFieldDef({
    required this.id,
    required this.label,
    required this.hint,
    this.kind = InstanceConfigFieldKind.text,
  });

  final String id;
  final String label;
  final String hint;
  final InstanceConfigFieldKind kind;
}

class InstanceConfigSectionDef {
  const InstanceConfigSectionDef({
    required this.title,
    required this.subtitle,
    required this.fields,
  });

  final String title;
  final String subtitle;
  final List<InstanceConfigFieldDef> fields;
}

abstract final class InstanceConfigSchema {
  static const displayNameKey = 'instance.display_name';
  static const imServerIdKey = 'instance.im_server_id';
  static const brandingKey = 'instance.branding';
  static const legalKey = 'instance.legal';

  static const allowedTopLevelKeys = {
    displayNameKey,
    imServerIdKey,
    brandingKey,
    legalKey,
  };

  static const sections = [
    InstanceConfigSectionDef(
      title: 'Identità',
      subtitle: 'Nome e indirizzo del servizio mostrati in app',
      fields: [
        InstanceConfigFieldDef(
          id: 'display_name',
          label: 'Nome visualizzato',
          hint: 'Es. Alfred.im Demo',
        ),
        InstanceConfigFieldDef(
          id: 'im_server_id',
          label: 'ID server IM',
          hint: 'Es. alfred.im',
        ),
      ],
    ),
    InstanceConfigSectionDef(
      title: 'Shell / PWA',
      subtitle: 'Titolo browser, manifest e colori shell (opzionali)',
      fields: [
        InstanceConfigFieldDef(
          id: 'short_name',
          label: 'Nome breve',
          hint: 'Es. Alfred.im',
        ),
        InstanceConfigFieldDef(
          id: 'description',
          label: 'Descrizione',
          hint: 'Messaggistica consent-first',
        ),
        InstanceConfigFieldDef(
          id: 'theme_color',
          label: 'Colore tema',
          hint: '#2D2926',
          kind: InstanceConfigFieldKind.color,
        ),
        InstanceConfigFieldDef(
          id: 'background_color',
          label: 'Colore sfondo',
          hint: '#2D2926',
          kind: InstanceConfigFieldKind.color,
        ),
        InstanceConfigFieldDef(
          id: 'logo',
          label: 'Logo',
          hint: 'PNG, JPEG o WebP (max 2 MB)',
          kind: InstanceConfigFieldKind.asset,
        ),
        InstanceConfigFieldDef(
          id: 'favicon',
          label: 'Favicon',
          hint: 'PNG, JPEG, WebP o ICO (max 2 MB)',
          kind: InstanceConfigFieldKind.asset,
        ),
      ],
    ),
    InstanceConfigSectionDef(
      title: 'Legale',
      subtitle: 'Link nel footer auth (opzionali)',
      fields: [
        InstanceConfigFieldDef(
          id: 'privacy_url',
          label: 'Privacy',
          hint: 'https://…/privacy',
          kind: InstanceConfigFieldKind.url,
        ),
        InstanceConfigFieldDef(
          id: 'terms_url',
          label: 'Termini',
          hint: 'https://…/terms',
          kind: InstanceConfigFieldKind.url,
        ),
        InstanceConfigFieldDef(
          id: 'support_url',
          label: 'Supporto',
          hint: 'https://…/support',
          kind: InstanceConfigFieldKind.url,
        ),
      ],
    ),
  ];
}
