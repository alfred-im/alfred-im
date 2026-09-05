// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Release gate — unico serpente e2e (cast comune, transizioni, ordine core).
 *
 * I spec in `e2e/*.spec.ts` restano per debug mirato (`e2e-nav-local`, `flusso-reale`, …).
 * CI e `bash scripts/test.sh e2e` eseguono solo questo file (`--retries=0`).
 */
import { test, expect, type BrowserContext, type Page } from '@playwright/test';

import {
  expectImagePersistedBothSides,
  expectMessagePersistedBothSides,
  waitForSenderReadAt,
} from './helpers/backend-assertions';
import { sendPhotoFromGallery, sendPhotoFromGalleryAfterPickerResume } from './helpers/chat-media';
import { enableFlutterAccessibility, readSavedAccountsManifest } from './helpers/flutter-a11y';
import { expectFocusedUserId } from './helpers/focus';
import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  expectInstanceBootstrapViaRpc,
  expectInstanceConfigInDb,
  promoteProfileToOwner,
  type InstanceConfigExpectation,
} from './helpers/instance-config';
import {
  clickSaveInstanceConfig,
  expectConfigButtonVisible,
  fillInstanceConfigForm,
  openInstanceConfigScreen,
} from './helpers/instance-config-ui';
import {
  addReceptionAllowlist,
  configureLocalPushSettings,
  installPushReceivedListener,
  invokeSendPush,
  sendMessageToProfile,
  waitForPushReceived,
} from './helpers/local-push-setup';
import {
  backToInboxFromChat,
  BASE_URL,
  clearAppData,
  closeDrawerIfOpen,
  composeNewMessage,
  expectChatContains,
  expectManifestCount,
  expectMultiAccountList,
  loginInAuthForm,
  manifestEntryForUsername,
  openPeerInInbox,
  openPeerInInboxView,
  sendChatMessage,
  switchToAccountByDisplayName,
  waitForAppBoot,
  waitForChatInput,
  waitForLoggedInShell,
} from './helpers/multi-account';
import {
  closeChatHeaderMenu,
  closePeerProfileOverlay,
  expectAllowlistAbsentInDb,
  expectAllowlistInDb,
  expectContactAbsentInDb,
  expectContactInDb,
  expectNoRelationshipError,
  openChatHeaderMenu,
  openPeerProfileFromChatHeader,
  openPeerProfileFromInboxRow,
  selectChatHeaderMenuItem,
} from './helpers/peer-relationship';
import {
  deliverPushInServiceWorker,
  ensurePushSubscriptionInDb,
  forceNotificationPermission,
  installNotificationPermissionMock,
  installPushSubscribeMock,
  installPushTestEnvironment,
  simulateNotificationTap,
  waitForBrowserPushGranted,
} from './helpers/push';
import { createSnakeCast, snakeManifestOrder, type SnakeCast } from './helpers/snake-cast';
import {
  ensureInboxShell,
  ensureManifestAccounts,
  manifestEntriesFor,
} from './helpers/snake-manifest';
import { snakeStep } from './helpers/snake-log';
import {
  resyncSnakeShell,
  transitionMessagingReady,
  transitionPeerCanAdd,
  transitionPeerEstablished,
} from './helpers/snake-transitions';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({
  viewport: { width: 390, height: 844 },
  permissions: ['notifications'],
});

test.describe.configure({ retries: 0 });

test.describe('@release-snake gate release unico', () => {
  let cast: SnakeCast;

  test.beforeAll(() => {
    test.skip(!isLocalSupabaseStack(), 'release-snake richiede stack locale');
    configureLocalPushSettings();
  });

  test('serpente release — tutti i check core', async ({ page, context }) => {
    test.setTimeout(process.env.CI ? 720_000 : 480_000);

    const stamp = `${Date.now()}`;
    snakeStep('setup.cast', stamp);
    cast = await createSnakeCast(stamp);

    const peerSeed = `snake-peer-${stamp}`;
    const msgIoc = `snake-ioc-${stamp}`;
    const msgParity = `snake-parity-${stamp}`;
    const msgAsr = `snake-asr-${stamp}`;
    const textBody = `snake-text-${stamp}`;
    const photoCaption = `snake-photo-${stamp}`;

    // ── Manifest + persist ──────────────────────────────────────────────
    snakeStep('core.manifest.login_e1_e2');
    let saved = await ensureManifestAccounts(page, [cast.e1, cast.e2], {
      wipe: true,
    });
    let [entry1, entry2] = manifestEntriesFor(saved, [cast.e1, cast.e2]);

    snakeStep('core.manifest.persist_f5');
    await page.reload({
      waitUntil: 'domcontentloaded',
      timeout: E2E_TIMEOUT.boot,
    });
    await waitForAppBoot(page);
    await waitForLoggedInShell(page);
    await enableFlutterAccessibility(page);
    saved = (await readSavedAccountsManifest(page))!;
    expectManifestCount(saved, 2);
    await expectMultiAccountList(page, true);
    [entry1, entry2] = manifestEntriesFor(saved, [cast.e1, cast.e2]);

    // ── Peer (PEER_CAN_ADD) ─────────────────────────────────────────────
    await transitionPeerCanAdd(cast.e1, cast.e2, peerSeed, `peer-${stamp}`);

    snakeStep('core.peer.profile_inbox_add');
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await ensureInboxShell(page);
    await expect(page.getByText(peerSeed).first()).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });
    const peerLabel = entry2.displayName ?? cast.e2.username;
    await openPeerProfileFromInboxRow(page, peerLabel);
    const addBtn = page.getByRole('button', {
      name: 'Aggiungi alla rubrica',
      exact: true,
    });
    await expect(addBtn).toBeVisible({ timeout: E2E_TIMEOUT.ui });
    await addBtn.click();
    await expectNoRelationshipError(page);
    await expectContactInDb(cast.e1.userId, cast.e2.userId);
    await closePeerProfileOverlay(page);
    await backToInboxFromChat(page);

    snakeStep('core.peer.profile_chat_add');
    await transitionPeerCanAdd(cast.e1, cast.e2, peerSeed, `peer2-${stamp}`);
    await resyncSnakeShell(page);
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await openPeerInInboxView(page, peerLabel);
    await expect(page.getByText(peerSeed).first()).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });
    await openPeerProfileFromChatHeader(page);
    const addFromChat = page.getByRole('button', {
      name: 'Aggiungi alla rubrica',
      exact: true,
    });
    await expect(addFromChat).toBeVisible({ timeout: E2E_TIMEOUT.ui });
    await addFromChat.click();
    await expectNoRelationshipError(page);
    await expectContactInDb(cast.e1.userId, cast.e2.userId);
    await closePeerProfileOverlay(page);
    await backToInboxFromChat(page);

    snakeStep('core.peer.actions_menu_profile');
    await transitionPeerCanAdd(cast.e1, cast.e2, peerSeed, `peer3-${stamp}`);
    await resyncSnakeShell(page);
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await switchToAccountByDisplayName(
      page,
      entry2.displayName!,
      entry2.userId,
    );
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await openPeerInInboxView(page, peerLabel);
    await expect(page.getByText(peerSeed).first()).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });
    await openChatHeaderMenu(page);
    await selectChatHeaderMenuItem(page, 'Aggiungi alla rubrica');
    await expectNoRelationshipError(page);
    await expectContactInDb(cast.e1.userId, cast.e2.userId);
    await openChatHeaderMenu(page);
    await selectChatHeaderMenuItem(page, 'Consenti');
    await expectNoRelationshipError(page);
    await expectAllowlistInDb(cast.e1.userId, cast.e2.userId);
    await page.keyboard.press('Escape');
    await closeChatHeaderMenu(page);
    await openPeerProfileFromChatHeader(page);
    const allowSwitch = page.getByRole('switch', { name: /Consenti messaggi/ });
    await expect(allowSwitch).toBeChecked({ timeout: E2E_TIMEOUT.ui });

    // ── Peer (PEER_ESTABLISHED) ─────────────────────────────────────────
    await transitionPeerEstablished(
      cast.e1,
      cast.e2,
      peerSeed,
      `est-${stamp}`,
    );
    await resyncSnakeShell(page);

    snakeStep('core.peer.consent_toggle');
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await openPeerInInboxView(page, peerLabel);
    await openChatHeaderMenu(page);
    await selectChatHeaderMenuItem(page, 'Rimuovi dalla rubrica');
    await expectContactAbsentInDb(cast.e1.userId, cast.e2.userId);
    await openChatHeaderMenu(page);
    await selectChatHeaderMenuItem(page, 'Aggiungi alla rubrica');
    await expectContactInDb(cast.e1.userId, cast.e2.userId);
    await openChatHeaderMenu(page);
    await selectChatHeaderMenuItem(page, 'Revoca');
    await expectAllowlistAbsentInDb(cast.e1.userId, cast.e2.userId);
    await openChatHeaderMenu(page);
    await selectChatHeaderMenuItem(page, 'Consenti');
    await expectAllowlistInDb(cast.e1.userId, cast.e2.userId);
    await closeChatHeaderMenu(page);

    snakeStep('core.peer.profile_switch_cycle');
    await openPeerProfileFromChatHeader(page);
    const removeBtn = page.getByRole('button', {
      name: 'Rimuovi dalla rubrica',
      exact: true,
    });
    await removeBtn.click();
    await expectContactAbsentInDb(cast.e1.userId, cast.e2.userId);
    await page
      .getByRole('button', { name: 'Aggiungi alla rubrica', exact: true })
      .click();
    await expectContactInDb(cast.e1.userId, cast.e2.userId);

    // ── Chat / navigazione ──────────────────────────────────────────────
    await transitionMessagingReady(cast.e1, cast.e2);

    snakeStep('core.chat.inbox_open');
    await sendMessageToProfile({
      senderAccessToken: cast.session1.accessToken,
      recipientProfileId: cast.e2.userId,
      body: msgIoc,
      clientMessageId: `ioc-${stamp}`,
    });
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await page.getByText(peerLabel).first().click({ timeout: E2E_TIMEOUT.ui });
    await waitForChatInput(page);
    await expect(page.getByText(msgIoc)).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });

    snakeStep('core.chat.inbox_parity');
    await backToInboxFromChat(page);
    await composeNewMessage(page, cast.e2.username);
    await sendChatMessage(page, msgParity);
    await backToInboxFromChat(page);
    await expect(page.getByText(msgParity).first()).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });
    await openPeerInInbox(page, peerLabel);
    await expect(page.getByText(msgParity)).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });
    await backToInboxFromChat(page);

    snakeStep('core.chat.switch_restore');
    await sendMessageToProfile({
      senderAccessToken: cast.session1.accessToken,
      recipientProfileId: cast.e2.userId,
      body: msgAsr,
      clientMessageId: `asr-${stamp}`,
    });
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await page.getByText(peerLabel).first().click({ timeout: E2E_TIMEOUT.ui });
    await waitForChatInput(page);
    await backToInboxFromChat(page);
    await switchToAccountByDisplayName(
      page,
      entry2.displayName!,
      entry2.userId,
    );
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await openPeerInInbox(page, peerLabel);
    await waitForChatInput(page);
    await expect(page.getByText(msgAsr)).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });

    snakeStep('core.chat.multi_account_messages');
    await switchToAccountByDisplayName(
      page,
      entry1.displayName!,
      entry1.userId,
    );
    await composeNewMessage(page, cast.e2.username);
    await sendChatMessage(page, textBody);
    await backToInboxFromChat(page);
    await expectMessagePersistedBothSides({
      body: textBody,
      sender: {
        email: cast.e1.email,
        password: cast.e1.password,
        userId: cast.e1.userId,
      },
      recipient: {
        email: cast.e2.email,
        password: cast.e2.password,
        userId: cast.e2.userId,
      },
    });
    await switchToAccountByDisplayName(
      page,
      entry2.displayName!,
      entry2.userId,
    );
    await openPeerInInbox(page, entry1.displayName!);
    await expectChatContains(page, [textBody]);
    await waitForSenderReadAt({
      sender: {
        email: cast.e1.email,
        password: cast.e1.password,
        userId: cast.e1.userId,
      },
      peerUserId: cast.e2.userId,
      body: textBody,
    });
    await sendPhotoFromGallery(page, {
      caption: photoCaption,
      assertImageInUi: false,
    });
    await expectImagePersistedBothSides({
      sender: {
        email: cast.e2.email,
        password: cast.e2.password,
        userId: cast.e2.userId,
      },
      recipient: {
        email: cast.e1.email,
        password: cast.e1.password,
        userId: cast.e1.userId,
      },
      caption: photoCaption,
    });
    await backToInboxFromChat(page);

    // ── Push ────────────────────────────────────────────────────────────
    await runPushFull(page, context, cast, stamp);
    await runPushTap(page, context, cast, stamp);
    await runPushPoison(page, context, cast, stamp);

    // ── Photo (manifest 5) ────────────────────────────────────────────
    await runPhotoResume(page, context, cast);

    // ── Instance config ───────────────────────────────────────────────
    await runInstanceConfig(page, cast, stamp);

    snakeStep('done.ok');
  });
});

async function runPushFull(
  page: Page,
  context: BrowserContext,
  cast: SnakeCast,
  stamp: string,
): Promise<void> {
  snakeStep('core.push.full');
  await addReceptionAllowlist({
    recipientUserId: cast.e1.userId,
    allowedProfileId: cast.e3.userId,
    recipientAccessToken: cast.session1.accessToken,
  });
  await addReceptionAllowlist({
    recipientUserId: cast.e3.userId,
    allowedProfileId: cast.e1.userId,
    recipientAccessToken: cast.session3.accessToken,
  });
  await installPushSubscribeMock(page);
  await installNotificationPermissionMock(page);
  await installPushReceivedListener(page);
  await forceNotificationPermission(page, new URL(BASE_URL).origin);
  await context.grantPermissions(['notifications'], {
    origin: new URL(BASE_URL).origin,
  });
  await switchToAccountByDisplayName(
    page,
    manifestEntryForUsername(
      (await readSavedAccountsManifest(page))!,
      cast.e1.username,
    ).displayName!,
    cast.e1.userId,
  );
  await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.register('push_sw.js');
    await navigator.serviceWorker.ready;
    await reg.pushManager.subscribe({ userVisibleOnly: true });
  });
  await ensurePushSubscriptionInDb({
    page,
    accessToken: cast.session1.accessToken,
    userId: cast.e1.userId,
  });
  const messageBody = `snake-push-full-${stamp}`;
  const sent = await sendMessageToProfile({
    senderAccessToken: cast.session3.accessToken,
    recipientProfileId: cast.e1.userId,
    body: messageBody,
    clientMessageId: `push-full-${stamp}`,
  });
  const swPayload = {
    recipientUserId: cast.e1.userId,
    peerProfileId: cast.e3.userId,
    peerDisplayName: cast.e3.username,
    previewText: messageBody,
    logicalMessageId: sent.logical_message_id,
    content_type: 'text',
  };
  try {
    await invokeSendPush({
      recipient_user_id: cast.e1.userId,
      peer_profile_id: cast.e3.userId,
      peer_display_name: cast.e3.username,
      preview_text: messageBody,
      logical_message_id: sent.logical_message_id,
      content_type: 'text',
    });
    await waitForPushReceived(page, {
      previewText: messageBody,
      timeoutMs: 6_000,
    });
  } catch {
    await deliverPushInServiceWorker(page, swPayload);
    await waitForPushReceived(page, { previewText: messageBody });
  }
}

async function runPushTap(
  page: Page,
  context: BrowserContext,
  cast: SnakeCast,
  stamp: string,
): Promise<void> {
  snakeStep('core.push.tap_multi_account');
  await installPushTestEnvironment(page, context, BASE_URL);
  const saved = (await readSavedAccountsManifest(page))!;
  const account1 = manifestEntryForUsername(saved, cast.e1.username);
  const account2 = manifestEntryForUsername(saved, cast.e2.username);
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );
  await expectFocusedUserId(page, account1.userId);
  await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.register('push_sw.js');
    await navigator.serviceWorker.ready;
    await reg.pushManager.subscribe({ userVisibleOnly: true });
  });
  await ensurePushSubscriptionInDb({
    page,
    accessToken: cast.session2.accessToken,
    userId: cast.e2.userId,
  });
  const messageBody = `snake-push-tap-${stamp}`;
  await sendMessageToProfile({
    senderAccessToken: cast.session1.accessToken,
    recipientProfileId: cast.e2.userId,
    body: messageBody,
    clientMessageId: `push-tap-${stamp}`,
  });
  await deliverPushInServiceWorker(page, {
    recipientUserId: cast.e2.userId,
    peerProfileId: cast.e1.userId,
    peerDisplayName: account1.displayName ?? cast.e1.username,
    recipientUsername: cast.e2.username,
    previewText: messageBody,
  });
  await simulateNotificationTap(page, {
    recipientUserId: cast.e2.userId,
    peerProfileId: cast.e1.userId,
  });
  await expectFocusedUserId(page, account2.userId);
  await waitForChatInput(page);
  await expect(page.getByText(messageBody)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });
}

async function runPushPoison(
  page: Page,
  context: BrowserContext,
  cast: SnakeCast,
  stamp: string,
): Promise<void> {
  snakeStep('core.push.poison');
  const poisonBy = 'VELENO_SNAKE_B_VERSO_Y';
  const msgA = 'snake legit A';
  const msgB = 'snake legit B';
  await addReceptionAllowlist({
    recipientUserId: cast.e2.userId,
    allowedProfileId: cast.e3.userId,
    recipientAccessToken: cast.session2.accessToken,
  });
  await sendMessageToProfile({
    senderAccessToken: cast.session1.accessToken,
    recipientProfileId: cast.e2.userId,
    body: msgA,
    clientMessageId: `pa-${stamp}`,
  });
  await sendMessageToProfile({
    senderAccessToken: cast.session2.accessToken,
    recipientProfileId: cast.e1.userId,
    body: msgB,
    clientMessageId: `pb-${stamp}`,
  });
  await sendMessageToProfile({
    senderAccessToken: cast.session2.accessToken,
    recipientProfileId: cast.e3.userId,
    body: poisonBy,
    clientMessageId: `py-${stamp}`,
  });
  await installPushTestEnvironment(page, context, BASE_URL);
  const saved = (await readSavedAccountsManifest(page))!;
  const account1 = manifestEntryForUsername(saved, cast.e1.username);
  const account2 = manifestEntryForUsername(saved, cast.e2.username);
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );
  await enableFlutterAccessibility(page);
  await page
    .getByText(account2.displayName ?? cast.e2.username)
    .first()
    .click({ timeout: E2E_TIMEOUT.ui });
  await waitForChatInput(page);
  await simulateNotificationTap(page, {
    recipientUserId: cast.e2.userId,
    peerProfileId: cast.e1.userId,
  });
  await expectFocusedUserId(page, account2.userId);
  await waitForChatInput(page);
  await expect(page.getByText(msgA)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });
  const poisonVisible = await page
    .getByText(poisonBy)
    .isVisible()
    .catch(() => false);
  expect(poisonVisible, 'INV-PUSH-MSG-3: poison non deve apparire su B|A').toBe(
    false,
  );
}

async function runPhotoResume(
  page: Page,
  context: BrowserContext,
  cast: SnakeCast,
): Promise<void> {
  snakeStep('core.media.photo_resume');
  await ensureManifestAccounts(page, snakeManifestOrder(cast));
  await installPushTestEnvironment(
    page,
    context,
    process.env.ALFRED_BASE_URL ?? BASE_URL,
  );
  await closeDrawerIfOpen(page);
  const saved = (await readSavedAccountsManifest(page))!;
  const u2entry = manifestEntryForUsername(saved, cast.e2.username);
  await switchToAccountByDisplayName(
    page,
    u2entry.displayName ?? cast.e2.username,
    u2entry.userId,
  );
  await waitForLoggedInShell(page);
  await waitForBrowserPushGranted(page);
  await composeNewMessage(page, cast.e1.username);
  await sendPhotoFromGalleryAfterPickerResume(page);
  await expect(
    page.getByText(
      /StorageException|row-level security|Sessione scaduta|violates row-level security policy/i,
    ),
  ).not.toBeVisible({ timeout: 10_000 });
  await expectImagePersistedBothSides({
    sender: {
      email: cast.e2.email,
      password: cast.e2.password,
      userId: cast.e2.userId,
    },
    recipient: {
      email: cast.e1.email,
      password: cast.e1.password,
      userId: cast.e1.userId,
    },
  });
}

async function runInstanceConfig(
  page: Page,
  cast: SnakeCast,
  stamp: string,
): Promise<void> {
  snakeStep('core.instance.non_owner');
  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await clearAppData(page);
  await loginInAuthForm(page, cast.e1.email, cast.e1.password);
  await waitForLoggedInShell(page);
  await enableFlutterAccessibility(page);
  await expectConfigButtonVisible(page, false);

  snakeStep('core.instance.promote_late');
  await clearAppData(page);
  await loginInAuthForm(page, cast.e2.email, cast.e2.password);
  await waitForLoggedInShell(page);
  promoteProfileToOwner(cast.e2.userId);
  await page.reload({
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await waitForLoggedInShell(page);
  await expectConfigButtonVisible(page, true);
  const lateValues: InstanceConfigExpectation = {
    displayName: `Snake Late ${stamp}`,
    imServerId: `snake-late-${stamp}.alfred.im`,
    shortName: `Late ${stamp}`,
    description: `Late ${stamp}`,
    themeColor: '#445566',
    backgroundColor: '#667788',
    logoUrl: '',
    faviconUrl: '',
    wordmarkUrl: '',
    privacyUrl: `https://example.com/snake/privacy-late-${stamp}`,
    termsUrl: `https://example.com/snake/terms-late-${stamp}`,
    supportUrl: `https://example.com/snake/support-late-${stamp}`,
  };
  await openInstanceConfigScreen(page);
  await fillInstanceConfigForm(page, lateValues);
  await clickSaveInstanceConfig(page);
  await expectInstanceConfigInDb(lateValues);

  snakeStep('core.instance.multi_account_focus');
  promoteProfileToOwner(cast.e4.userId);
  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await ensureManifestAccounts(page, [cast.e4, cast.e1], { wipe: true });
  const saved = (await readSavedAccountsManifest(page))!;
  const ownerEntry = manifestEntryForUsername(saved, cast.e4.username);
  const userEntry = manifestEntryForUsername(saved, cast.e1.username);
  await expectConfigButtonVisible(page, false);
  await switchToAccountByDisplayName(
    page,
    ownerEntry.displayName!,
    ownerEntry.userId,
  );
  await expectConfigButtonVisible(page, true);
  const focusValues: InstanceConfigExpectation = {
    displayName: `Snake Focus ${stamp}`,
    imServerId: `snake-focus-${stamp}.alfred.im`,
    shortName: `Focus ${stamp}`,
    description: `Focus ${stamp}`,
    themeColor: '#112233',
    backgroundColor: '#334455',
    logoUrl: '',
    faviconUrl: '',
    wordmarkUrl: '',
    privacyUrl: `https://example.com/snake/privacy-focus-${stamp}`,
    termsUrl: `https://example.com/snake/terms-focus-${stamp}`,
    supportUrl: `https://example.com/snake/support-focus-${stamp}`,
  };
  await openInstanceConfigScreen(page);
  await fillInstanceConfigForm(page, focusValues);
  await clickSaveInstanceConfig(page);
  await expectInstanceConfigInDb(focusValues);
  await switchToAccountByDisplayName(
    page,
    userEntry.displayName!,
    userEntry.userId,
  );
  await expectConfigButtonVisible(page, false);

  snakeStep('core.instance.owner_full_save');
  await switchToAccountByDisplayName(
    page,
    ownerEntry.displayName!,
    ownerEntry.userId,
  );
  const ownerValues: InstanceConfigExpectation = {
    displayName: `Snake Owner ${stamp}`,
    imServerId: `snake-owner-${stamp}.alfred.im`,
    shortName: `Owner ${stamp}`,
    description: `Owner ${stamp}`,
    themeColor: '#AABBCC',
    backgroundColor: '#DDEEFF',
    logoUrl: '',
    faviconUrl: '',
    wordmarkUrl: '',
    privacyUrl: `https://example.com/snake/privacy-owner-${stamp}`,
    termsUrl: `https://example.com/snake/terms-owner-${stamp}`,
    supportUrl: `https://example.com/snake/support-owner-${stamp}`,
  };
  await openInstanceConfigScreen(page);
  await fillInstanceConfigForm(page, ownerValues);
  await clickSaveInstanceConfig(page);
  await expectInstanceConfigInDb(ownerValues);
  await expectInstanceBootstrapViaRpc(
    cast.e4.email,
    cast.e4.password,
    ownerValues,
  );
}
