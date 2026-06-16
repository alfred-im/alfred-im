import { createClient } from 'stanza'
import type { Agent } from 'stanza'
import plugins from 'stanza/plugins'
import { DEFAULT_RESOURCE, TIMEOUTS } from '../config/constants'

export type XmppConnectionSettings = {
  jid: string
  password: string
  resource?: string
}

import { parseJid as parseJidUtil } from '../utils/jid'

/**
 * Estrae dominio e username da un JID completo
 * Formato JID: [local@]domain[/resource]
 * 
 * @deprecated Usa parseJid da '../utils/jid' invece
 */
const parseJid = parseJidUtil

/**
 * Discovers XMPP server hostname using SRV records (RFC 6120)
 * Tries _xmpp-client._tcp.{domain} SRV record
 */
const discoverXmppServer = async (domain: string): Promise<string | null> => {
  try {
    // In browser, we can't do DNS SRV queries directly
    // We'll try to connect to the domain directly first
    // For proper SRV support, we'd need a backend or DNS-over-HTTPS
    // For now, return null to use domain directly
    console.debug('SRV discovery not available in browser, using domain directly:', domain)
    return null
  } catch (error) {
    console.debug('SRV discovery failed:', error)
    return null
  }
}

/**
 * Discovers WebSocket URL from domain using XEP-0156 (host-meta discovery)
 * Falls back to common patterns if discovery fails
 */
const discoverWebSocketUrl = async (domain: string): Promise<string> => {
  // Try XEP-0156 discovery via .well-known/host-meta
  try {
    const hostMetaUrl = `https://${domain}/.well-known/host-meta`
    const response = await fetch(hostMetaUrl, {
      method: 'GET',
      headers: { Accept: 'application/xrd+xml, application/xml, text/xml' },
    })

    if (response.ok) {
      const text = await response.text()
      
      // Try normal XML parsing first
      const parser = new DOMParser()
      const doc = parser.parseFromString(text, 'text/xml')
      
      // Check for parsing errors
      const parserError = doc.querySelector('parsererror')
      if (!parserError) {
        // XML is valid, parse normally
        const allLinks = doc.getElementsByTagName('Link')
        
        for (let i = 0; i < allLinks.length; i++) {
          const link = allLinks[i]
          const rel = link.getAttribute('rel')
          if (rel === 'urn:xmpp:alt-connections:websocket') {
            const href = link.getAttribute('href')
            if (href) {
              // Clean up any extra quotes or whitespace
              const cleanedHref = href.trim().replace(/["']+$/g, '').replace(/^["']+/g, '')
              console.debug('Discovered WebSocket URL via XEP-0156:', cleanedHref)
              return cleanedHref
            }
          }
        }
        console.debug('No WebSocket link found in host-meta XML')
      } else {
        // XML parsing failed - try regex extraction as fallback for malformed XML
        console.debug('XML parsing error, trying regex extraction')
        const wsMatch = text.match(/rel=["']urn:xmpp:alt-connections:websocket["'][^>]*href=["']([^"']+)["']+/i)
        if (wsMatch && wsMatch[1]) {
          const cleanedHref = wsMatch[1].trim().replace(/["']+$/g, '').replace(/^["']+/g, '')
          console.debug('Extracted WebSocket URL via regex (malformed XML):', cleanedHref)
          return cleanedHref
        }
      }
    } else {
      console.debug('host-meta response not OK:', response.status)
    }
  } catch (error) {
    // Network error or fetch failed
    console.debug('XEP-0156 host-meta discovery failed:', error)
  }

  // Fallback: try common WebSocket patterns according to XMPP conventions
  console.debug('Using fallback WebSocket URL strategies for domain:', domain)
  
  // Pattern 1: subdomain xmpp with /websocket path (common for conversations.im)
  const fallbackUrl1 = `wss://xmpp.${domain}:443/websocket`
  
  // Pattern 2: subdomain xmpp with /ws path (common for some servers)
  const fallbackUrl2 = `wss://xmpp.${domain}/ws`
  
  // Pattern 3: standard port 5281 with /xmpp-websocket path (RFC 7395)
  const fallbackUrl3 = `wss://${domain}:5281/xmpp-websocket`
  
  console.debug('Fallback options:', { fallbackUrl1, fallbackUrl2, fallbackUrl3 })
  
  // Return first fallback - the connection attempt will determine if it works
  // Stanza library will try multiple transports if needed
  return fallbackUrl1
}

export type XmppResult = {
  success: boolean
  message: string
  details?: string
  jid?: string
  client?: Agent // Include client quando success è true
}

type Intent = 'register' | 'login'

type RegistrationPayload = {
  jid: string
  username: string
  domain: string
  password: string
}

type GenericHandler = (...args: unknown[]) => void

const addCustomListener = (client: Agent, event: string, handler: GenericHandler, once = false) => {
  const emitter = client as unknown as {
    on: (name: string, cb: GenericHandler) => Agent
    once: (name: string, cb: GenericHandler) => Agent
  }

  if (once) {
    emitter.once(event, handler)
  } else {
    emitter.on(event, handler)
  }
}

const removeCustomListener = (client: Agent, event: string, handler: GenericHandler) => {
  const emitter = client as unknown as { removeListener: (name: string, cb: GenericHandler) => Agent }
  emitter.removeListener(event, handler)
}

const emitCustomEvent = (client: Agent, event: string, ...args: unknown[]) => {
  const emitter = client as unknown as { emit: (name: string, ...payload: unknown[]) => boolean }
  // Emit synchronously - handlers should be registered before this is called
  emitter.emit(event, ...args)
}

const buildClient = async (settings: XmppConnectionSettings): Promise<Agent> => {
  const { jid, password, resource = DEFAULT_RESOURCE } = settings
  
  // Parse JID to extract components
  const { username, domain, resource: jidResource } = parseJid(jid)
  
  if (!domain) {
    throw new Error('Il dominio del JID non può essere vuoto.')
  }
  
  if (!username) {
    throw new Error('Il JID deve contenere una parte locale (username).')
  }
  
  // Use resource from JID if present, otherwise use default
  const finalResource = jidResource || resource
  
  // Discover XMPP server (SRV records - not available in browser, use domain)
  const serverHost = await discoverXmppServer(domain) || domain
  
  // Discover WebSocket URL using XEP-0156
  const websocketUrl = await discoverWebSocketUrl(domain)
  
  // Build full JID with resource
  const fullJid = jidResource ? jid : `${username}@${domain}/${finalResource}`

  console.debug('Building XMPP client:', {
    jid: fullJid,
    server: serverHost,
    websocketUrl,
    domain,
  })

  const client = createClient({
    jid: fullJid,
    resource: finalResource,
    server: serverHost,
    lang: 'it',
    autoReconnect: false,
    timeout: 20,
    password,
    sendReceipts: true,
    chatMarkers: true,
    credentials: {
      username,
      password,
    },
    transports: {
      websocket: websocketUrl,
      bosh: false,
    },
  })

  // Carica plugin necessari (MAM, Roster)
  plugins(client)

  return client
}

const enableInBandRegistration = (client: Agent, payload: RegistrationPayload) => {
  let attempted = false

  client.registerFeature('inbandRegistration', 50, async (features, done) => {
    if (attempted) {
      done()
      return
    }

    attempted = true

    if (!features.inbandRegistration) {
      console.debug('Server does not support in-band registration')
      emitCustomEvent(client, 'register:unsupported')
      done()
      return
    }

    try {
      console.debug('Sending registration IQ for JID:', payload.jid)
      const result = await client.sendIQ({
        account: {
          username: payload.username,
          password: payload.password,
        },
        to: payload.domain,
        type: 'set',
      })
      console.debug('Registration IQ result:', result)
      
      // After successful registration, the client should automatically authenticate
      // with the newly created credentials. The client stanza library should handle
      // the SASL authentication flow automatically after registration.
      emitCustomEvent(client, 'register:completed')
      done()
    } catch (error: unknown) {
      console.error('Registration IQ error:', error)
      
      // Handle specific error conditions
      const err = error as { type?: string; error?: { condition?: string; text?: string }; condition?: string; text?: string; message?: string }
      if (err?.type === 'error') {
        const condition = err?.error?.condition || err?.condition
        if (condition === 'conflict') {
          emitCustomEvent(client, 'register:error', new Error('Username già esistente'))
        } else if (condition === 'not-allowed') {
          emitCustomEvent(client, 'register:error', new Error('Il server non permette la registrazione in-band. La funzionalità è disabilitata.'))
        } else {
          const errorMsg = err?.error?.text || err?.text || err?.message || 'Errore durante la registrazione'
          emitCustomEvent(client, 'register:error', new Error(errorMsg))
        }
      } else {
        emitCustomEvent(client, 'register:error', error instanceof Error ? error : new Error(String(error)))
      }
      done()
    }
  })
}

const runFlow = (client: Agent, intent: Intent): Promise<XmppResult> => {
  let settled = false
  let registerMessage = 'Account creato e autenticato.'
  const CONNECTION_TIMEOUT = TIMEOUTS.CONNECTION

  return new Promise((resolve) => {
    // Define handlers first
    const handleSessionStarted = () => {
      console.debug('Session started event received, JID:', client.jid)
      clearTimeout(timeoutId) // Cancel timeout immediately - we got a response
      const baseMessage =
        intent === 'register'
          ? registerMessage
          : 'Autenticazione completata con successo.'

      finish({
        success: true,
        message: baseMessage,
        jid: client.jid,
      }, true) // Mantieni connessione attiva
    }

    const handleAuthFailed = () => {
      clearTimeout(timeoutId) // Cancel timeout immediately - we got a response
      fail('Autenticazione rifiutata dal server XMPP.', 'Controlla JID/password o se il server richiede prerequisiti.')
    }

    const handleStreamError = (error: unknown) => {
      clearTimeout(timeoutId) // Cancel timeout immediately - we got a response
      // Check if it's a connection error (before authentication)
      const err = error as { condition?: string; text?: string }
      if (!settled && (err?.condition === 'connection-timeout' || err?.condition === 'host-unknown' || err?.condition === 'remote-connection-failed')) {
        handleConnectionError()
      } else if (!settled && err?.condition === 'policy-violation' && intent === 'register') {
        // Policy violation after registration attempt usually means registration was rejected
        // The register:error event should have been emitted, but if not, handle it here
        fail('Registrazione rifiutata dal server.', err?.text || 'Il server ha rifiutato la richiesta di registrazione.')
      } else {
        fail('Il server ha chiuso lo stream.', err?.text || err?.condition)
      }
    }

    const handleDisconnected = () => {
      clearTimeout(timeoutId) // Cancel timeout immediately - we got a response
      if (!settled) {
        fail('Connessione terminata prima di completare la procedura.')
      }
    }

    const handleRegisterCompleted = () => {
      console.debug('Registration completed event received')
      clearTimeout(timeoutId) // Cancel timeout - we got a response
      registerMessage = 'Account registrato e sessione aperta.'
      // Registration completed - the client should continue with SASL auth automatically
      // We wait for session:started which should come after successful authentication
      // If it doesn't come, we'll need a new timeout, but for now we got a response
    }

    const handleRegisterError = (error: unknown) => {
      console.error('Registration error event received:', error)
      clearTimeout(timeoutId) // Cancel timeout immediately - we got a response
      const err = error as { message?: string }
      fail('Registrazione fallita.', err?.message || 'Verifica che il server consenta la registrazione in-band.')
    }

    const handleRegisterUnsupported = () => {
      console.debug('Registration unsupported event received')
      clearTimeout(timeoutId) // Cancel timeout immediately - we got a response
      fail('Il server non supporta la registrazione in-band (XEP-0077).')
    }

    const handleConnectionError = () => {
      clearTimeout(timeoutId) // Cancel timeout immediately - we got a response
      // This handles WebSocket connection failures (including fallback failures)
      fail(
        'Impossibile connettersi al server XMPP tramite WebSocket.',
        'Il discovery automatico secondo XEP-0156 e i fallback standard hanno fallito. Verifica che il server sia raggiungibile e che supporti connessioni WebSocket.'
      )
    }

    // Enhanced disconnected handler to detect connection failures
    const handleDisconnectedWithError = () => {
      clearTimeout(timeoutId) // Cancel timeout immediately - we got a response
      if (!settled) {
        // If we disconnected before session started, it's a connection failure
        handleConnectionError()
      } else {
        // Normal disconnection after session
        handleDisconnected()
      }
    }

    // Cleanup function
    const cleanup = () => {
      clearTimeout(timeoutId)
      client.removeListener('session:started', handleSessionStarted)
      client.removeListener('auth:failed', handleAuthFailed)
      client.removeListener('stream:error', handleStreamError)
      client.removeListener('disconnected', handleDisconnectedWithError)
      removeCustomListener(client, 'register:completed', handleRegisterCompleted)
      removeCustomListener(client, 'register:error', handleRegisterError)
      removeCustomListener(client, 'register:unsupported', handleRegisterUnsupported)
    }

    const finish = (result: XmppResult, keepConnected = false) => {
      if (settled) {
        return
      }
      settled = true
      cleanup()
      // Solo disconnetti se non dobbiamo mantenere la connessione
      if (!keepConnected) {
        void client.disconnect()
      } else {
        // Se manteniamo la connessione, aggiungi il client al risultato
        result.client = client
      }
      resolve(result)
    }

    const fail = (message: string, details?: string) => {
      finish({
        success: false,
        message,
        details,
      })
    }

    // Timeout to prevent hanging indefinitely
    // This will be cleared as soon as we get ANY response from the server
    const startTime = Date.now()
    const timeoutId = setTimeout(() => {
      if (!settled) {
        const elapsed = Date.now() - startTime
        console.warn(`Connection timeout after ${elapsed}ms. No response from server.`)
        settled = true
        cleanup()
        void client.disconnect()
        resolve({
          success: false,
          message: 'Timeout: la connessione al server ha richiesto troppo tempo.',
          details: 'Verifica che il server sia raggiungibile e che supporti connessioni WebSocket.',
        })
      }
    }, CONNECTION_TIMEOUT)

    // Register event handlers BEFORE calling connect
    client.once('session:started', handleSessionStarted)
    client.once('auth:failed', handleAuthFailed)
    client.once('stream:error', handleStreamError)
    client.once('disconnected', handleDisconnectedWithError)
    addCustomListener(client, 'register:completed', handleRegisterCompleted)
    // Use once: true for error/unsupported to ensure they're only handled once
    addCustomListener(client, 'register:error', handleRegisterError, true)
    addCustomListener(client, 'register:unsupported', handleRegisterUnsupported, true)
    
    // DON'T call connect() here - let the caller do it after registerFeature is set
  })
}

const connectWithIntent = async (settings: XmppConnectionSettings, intent: Intent) => {
  const client = await buildClient(settings)

  // Parse JID for registration
  const { username, domain } = parseJid(settings.jid)

  // 1. Start the flow (registers event handlers, starts timeout, returns promise)
  const flowPromise = runFlow(client, intent)
  
  // 2. Enable registration feature if needed (must be before connect())
  if (intent === 'register') {
    enableInBandRegistration(client, {
      jid: settings.jid,
      username,
      domain,
      password: settings.password,
    })
  }

  // 3. Now start the connection (handlers are registered, features are set)
  try {
    console.debug('Attempting to connect to:', client.config.transports?.websocket)
    client.connect()
  } catch (error) {
    // Synchronous connection error - this should be rare
    console.error('Synchronous connection error:', error)
    // The promise will timeout or be rejected by event handlers
  }

  return flowPromise
}

export const registerAccount = async (
  settings: XmppConnectionSettings,
): Promise<XmppResult> => connectWithIntent(settings, 'register')

export const login = async (
  settings: XmppConnectionSettings,
): Promise<XmppResult> => connectWithIntent(settings, 'login')
