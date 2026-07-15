# SYS-PUSH — Notifiche Web Push (VAPID)

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-PUSH` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-15 |
| **Contratti** | [schema.md](../../contracts/schema.md) · [rpc.md](../../contracts/rpc.md) |
| **Correlata** | [SYS-DELIVERY](./SYS-DELIVERY.md), [SYS-RECEPTION](./SYS-RECEPTION.md), [SYS-ACCOUNT-BOUNDARY](./SYS-ACCOUNT-BOUNDARY.md) |

Promessa SYSTEM — infrastruttura **non-account** per notifiche Web Push VAPID: persistenza subscription, invio post-recapito, Edge Function `send-push`.

**Dettaglio canonico**: [contracts/schema.md](../../contracts/schema.md) § `push_subscriptions` · [contracts/rpc.md](../../contracts/rpc.md)

---

## 1. Problema / obiettivo

L'utente Alfred riceve notifiche su **tutti i dispositivi** dove ha aperto un account, e su un dispositivo riceve notifiche per **tutti gli account** nel manifest — anche quelli non in focus. L'invio avviene solo dopo recapito riuscito ([SYS-DELIVERY](./SYS-DELIVERY.md) + gate [SYS-RECEPTION](./SYS-RECEPTION.md)).

---

## 2. Promesse

### SCHEMA — `push_subscriptions`

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-PUSH-001** | Tabella `push_subscriptions`: `id` uuid PK, `user_id` FK → `auth.users`, `device_id` uuid NOT NULL, `endpoint` text NOT NULL, `p256dh_key` text NOT NULL, `auth_key` text NOT NULL, `user_agent` text nullable, `created_at` timestamptz, `last_seen_at` timestamptz |
| **SYS-PUSH-002** | UNIQUE `(user_id, device_id)` — un record per account per dispositivo |
| **SYS-PUSH-003** | UNIQUE `(user_id, device_id)` — un record per account Alfred per dispositivo; UNIQUE `(user_id, endpoint)` — stesso endpoint FCM può essere condiviso da account diversi sullo stesso browser (multi-account), ma non duplicato per lo stesso account |
| **SYS-PUSH-004** | RLS: SELECT, INSERT, UPDATE, DELETE solo `user_id = auth.uid()` |
| **SYS-PUSH-005** | Nessun `GRANT` invio push a `authenticated` — solo infrastruttura delivery / Edge Function |

### VAPID — chiavi e Edge Function

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-PUSH-010** | Coppia chiavi VAPID: public esposta al client (env / config); private solo secret Supabase Edge Function |
| **SYS-PUSH-011** | Edge Function `send-push` (Deno): invoca libreria `web-push` con VAPID; input JSON payload notifica |
| **SYS-PUSH-012** | Edge Function invocata solo da infrastruttura server (Database Webhook, `pg_net`, o hook post-delivery worker) — **non** dal client |
| **SYS-PUSH-013** | Risposta `410 Gone` dal push service → DELETE subscription corrispondente (`endpoint`) |

### INVIO — post-recapito

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-PUSH-020** | Push inviata **solo** dopo INSERT copia destinatario riuscito in `alfred_delivery.deliver_internal` (o erogazione gruppo equivalente) |
| **SYS-PUSH-021** | Nessuna push su rifiuto silenzioso allow list ([SYS-RECEPTION](./SYS-RECEPTION.md)) |
| **SYS-PUSH-022** | Payload push include: `recipient_user_id`, `peer_profile_id`, `peer_display_name`, `recipient_display_name`, `recipient_username`, `preview_text`, `logical_message_id`, `content_type` |
| **SYS-PUSH-023** | Invio a **tutte** le righe `push_subscriptions` WHERE `user_id = recipient_user_id` |
| **SYS-PUSH-024** | Gruppi: stesso contratto invio — `recipient_user_id` = owner archivio che riceve (umano o gruppo); nessuna esclusione per `profile_kind` |
| **SYS-PUSH-025** | Hook delivery: dopo recapito, accoda `outbox` con `event_kind = push_notify` oppure invoca direttamente Edge Function da worker (implementazione equivalente, un solo percorso in produzione) |
| **SYS-PUSH-026** | Identità push server = coppia **`(recipient_user_id, peer_profile_id)`** obbligatoria; nessun evento `push_notify` valido se manca un membro della coppia |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-PUSH-030** | Push con contenuto messaggio se recapito non materializzato |
| **SYS-PUSH-031** | Leak metadati su messaggio rifiutato da allow list |
| **SYS-PUSH-032** | Client che invoca `send-push` con payload arbitrario |
| **SYS-PUSH-033** | Subscription cross-user (RLS bypass) |
| **SYS-PUSH-034** | Payload `push_notify` o notifica inviata con solo `peer_profile_id` (senza `recipient_user_id`) |

---

## 3. Implementazione contratto

| Elemento | Responsabilità |
|----------|----------------|
| `push_subscriptions` | DDL + RLS in migrazione Supabase |
| `alfred_delivery` | Estensione post-deliver → evento `push_notify` — vedi [SYS-DELIVERY](./SYS-DELIVERY.md) § push |
| `supabase/functions/send-push/` | Edge Function Deno + `web-push` |
| Secret `VAPID_PRIVATE_KEY` | Dashboard Supabase / deploy |
| Client public key | `client/lib/config/` o `--dart-define=VAPID_PUBLIC_KEY` |

---

## 4. Tracciabilità

| SYS-ID | Verifica |
|--------|----------|
| SYS-PUSH-001–004 | `supabase/tests/push_subscriptions_schema_smoke.sql` |
| SYS-PUSH-003 | `supabase/tests/push_multi_account_endpoint_smoke.sql` |
| SYS-PUSH-004–005 | `supabase/tests/push_subscriptions_rls_smoke.sql` |
| SYS-PUSH-020–021 | `supabase/tests/push_delivery_trigger_smoke.sql`; `supabase/tests/push_deliver_idempotent_smoke.sql` |
| SYS-PUSH-010–013 | `supabase/functions/send-push/index.ts`; `client/e2e/push-full.spec.ts` (invio locale) |
| SYS-PUSH-023 | `supabase/tests/push_multi_device_smoke.sql` |
| SYS-PUSH-013 | `supabase/functions/send-push/index.ts` (cleanup endpoint 410) |

**Gate**: `bash scripts/check-spec-sync.sh` + smoke SQL + `bash scripts/test.sh integration-push` (post-implementazione)

---

## 5. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [SYS-DELIVERY](./SYS-DELIVERY.md) | Hook post-recapito `push_notify` |
| [PROM-PUSH-NOTIFY](../product/PROM-PUSH-NOTIFY.md) | Regole prodotto multi-device / multi-account |
| [SURF-NOTIFICATIONS](../../surfaces/SURF-NOTIFICATIONS.md) | Service worker e permesso browser |
| [registry.md](../../registry.md) | Indice promesse |
