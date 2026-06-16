// XMPP Configuration
export const DEFAULT_XMPP_DOMAIN = 'jabber.hot-chilli.net';
export const DEFAULT_XMPP_WEBSOCKET = 'wss://jabber.hot-chilli.net:5281/xmpp-websocket';
export const DEFAULT_RESOURCE = 'web-messaging-app';

// UI Configuration
export const UI = {
  appName: 'Alfred',
} as const;

// Pagination & Loading
export const PAGINATION = {
  DEFAULT_MESSAGE_LIMIT: 50,
  DEFAULT_CONVERSATION_LIMIT: 100,
  LOAD_MORE_THRESHOLD: 200, // px from top to trigger load more
  SCROLL_BOTTOM_THRESHOLD: 1, // px from bottom to consider "at bottom" (minimal tolerance for rounding)
} as const;

// Message Status
export const MESSAGE_STATUS = {
  PENDING: 'pending',
  SENT: 'sent',
  DELIVERED: 'delivered',
  FAILED: 'failed',
} as const;

// Timeouts & Delays
export const TIMEOUTS = {
  CONNECTION: 5000, // ms - XMPP connection timeout
} as const;

// Sync boundary: margine di sovrapposizione tra MAM e listener (skew orologi client/server)
export const SYNC = {
  /** MAM scarica fino a T + overlap; il listener parte da T. I doppioni sono gestiti da messageId. */
  BOUNDARY_OVERLAP_MS: 5000,
} as const;

// Text Limits
export const TEXT_LIMITS = {
  MAX_MESSAGE_PREVIEW_LENGTH: 50,
  MAX_JID_LENGTH: 1023,
  MAX_TEXTAREA_HEIGHT: 120, // px
} as const;

// Storage Keys
export const STORAGE_KEYS = {
  JID: 'xmpp_jid',
  PASSWORD: 'xmpp_password',
} as const;
