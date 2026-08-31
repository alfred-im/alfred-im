# SURF-INSTANCE-CONFIG — Configurazione istanza (owner)

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-INSTANCE-CONFIG` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-08-31 |
| **Promesse** | [SYS-OWNER](../promises/system/SYS-OWNER.md) |

Schermata owner per editing `instance_config`: identità servizio, shell/PWA e link legali.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Widget / schermata | `client/lib/screens/instance_config_screen.dart` |
| Schema form | `client/lib/models/instance_config_schema.dart` |
| Upload branding | `client/lib/services/instance_branding_service.dart` |
| RPC save | `OwnerService.saveInstanceSettings` → `upsert_instance_config` |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-INSTANCE-CONFIG-001** | Visibile solo se `is_instance_owner()` |
| **SURF-INSTANCE-CONFIG-002** | Form fisso su 10 campi: `display_name`, `im_server_id`, `short_name`, `description`, `theme_color`, `background_color`, logo (file), favicon (file), `privacy_url`, `terms_url`, `support_url` |
| **SURF-INSTANCE-CONFIG-003** | Logo e favicon: solo picker file + rimuovi — **nessun** campo URL manuale |
| **SURF-INSTANCE-CONFIG-004** | Upload Storage bucket `instance-branding` **solo su Salva**; path versionato (`branding/{logo\|favicon}/{uuid}.ext`); sostituzione elimina blob precedente |
| **SURF-INSTANCE-CONFIG-005** | Dopo save: `upsert_instance_config` sulle quattro chiavi top-level + reload `InstanceRuntime` |
| **SURF-INSTANCE-CONFIG-006** | Multi-account: load/save sul account in focus; messaggio chiaro se non owner |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-INSTANCE-CONFIG-010** | Scrivere file statici shell (`index.html`, `manifest.json`) nel deploy client |
| **SURF-INSTANCE-CONFIG-011** | Upload logo/favicon prima del click Salva |

---

## 3. Tracciabilità

| SURF-ID | Verifica |
|---------|----------|
| `SURF-INSTANCE-CONFIG-002` | `client/test/unit/instance_config_schema_test.dart` |
| `SURF-INSTANCE-CONFIG-005` | `client/e2e/instance-config-panel.spec.ts` |
| `SURF-INSTANCE-CONFIG-001` | `client/e2e/instance-config-panel.spec.ts` (non-owner) |

---

## 4. Riferimenti

- [registry.md](../registry.md)
- Gateway shell dinamica: `client/deploy/gateway/`
