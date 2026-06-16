import { useState } from 'react'
import type { ChangeEvent, FormEvent } from 'react'
import { useConnection } from '../contexts/ConnectionContext'
import { isValidJid, parseJid } from '../utils/jid'
import { TEXT_LIMITS } from '../config/constants'
import './LoginPopup.css'

type AsyncState = 'idle' | 'pending' | 'success' | 'error'

type FormStatus = {
  state: AsyncState
  message?: string
  details?: string
}

const initialStatus: FormStatus = { state: 'idle' }

/**
 * Valida e normalizza un username completo (formato: username@server.com)
 * 
 * @param input - Il JID da validare e normalizzare
 * @returns Oggetto con validità, JID normalizzato e eventuale errore
 */
const validateAndNormalizeJid = (input: string): { valid: boolean; jid?: string; error?: string } => {
  const trimmed = input.trim()
  
  if (!trimmed) {
    return { valid: false, error: 'Inserisci il tuo username completo.' }
  }

  if (!isValidJid(trimmed)) {
    if (!trimmed.includes('@')) {
      return { valid: false, error: 'Inserisci il tuo username completo nel formato: username@server.com' }
    }
    
    const parts = trimmed.split('@')
    if (parts.length !== 2) {
      return { valid: false, error: 'Formato non valido. Usa: username@server.com' }
    }
    
    const [local, domainPart] = parts
    const [domain] = domainPart.split('/')
    
    if (local && local.length > TEXT_LIMITS.MAX_JID_LENGTH) {
      return { valid: false, error: 'Lo username è troppo lungo.' }
    }
    
    if (!domain || domain.length === 0) {
      return { valid: false, error: 'Inserisci anche il server (esempio: username@server.com).' }
    }
    
    if (domain.length > TEXT_LIMITS.MAX_JID_LENGTH) {
      return { valid: false, error: 'Il nome del server è troppo lungo.' }
    }
    
    return { valid: false, error: 'Formato JID non valido.' }
  }

  // JID valido, normalizzalo
  const parsed = parseJid(trimmed)
  const normalizedJid = parsed.username 
    ? `${parsed.username}@${parsed.domain}${parsed.resource ? `/${parsed.resource}` : ''}`
    : parsed.domain

  return { valid: true, jid: normalizedJid }
}

interface LoginPopupProps {
  isInitializing?: boolean
}

export function LoginPopup({ isInitializing }: LoginPopupProps) {
  const { connect, jid } = useConnection()
  const [loginForm, setLoginForm] = useState({
    jid: jid || '',  // Pre-compila con ultimo JID se disponibile
    password: ''
  })
  const [loginStatus, setLoginStatus] = useState<FormStatus>(initialStatus)

  const handleLoginChange = (field: 'jid' | 'password') => (event: ChangeEvent<HTMLInputElement>) => {
    setLoginForm((prev) => ({ ...prev, [field]: event.target.value }))
    setLoginStatus(initialStatus)
  }

  const handleLoginSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (loginStatus.state === 'pending') {
      return
    }

    const jidValidation = validateAndNormalizeJid(loginForm.jid)
    if (!jidValidation.valid) {
      setLoginStatus({ state: 'error', message: jidValidation.error || 'Username non valido.' })
      return
    }

    const password = loginForm.password

    if (!password) {
      setLoginStatus({ state: 'error', message: 'Inserisci la password per continuare.' })
      return
    }

    setLoginStatus({ state: 'pending', message: 'Connessione al server...' })

    const result = await connect(jidValidation.jid!, password)
    if (!result.success) {
      setLoginStatus({
        state: 'error',
        message: 'Impossibile connettersi al server.',
        details: result.error,
      })
      return
    }

    setLoginStatus({
      state: 'success',
      message: 'Accesso completato con successo!',
    })
    // Il popup si chiuderà automaticamente quando isConnected diventa true
  }

  return (
    <div 
      className="login-popup-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="login-title"
      aria-describedby="login-description"
    >
      <div className="login-popup-modal">
        {isInitializing ? (
          // Modalità 1: Caricamento durante auto-login
          <div className="login-popup-loading" role="status" aria-live="polite">
            <div className="login-popup-spinner" aria-hidden="true"></div>
            <p className="login-popup-loading-text">Connessione in corso...</p>
          </div>
        ) : (
          // Modalità 2: Form di login
          <>
            <div className="login-popup-header">
              <h2 id="login-title">Connessione richiesta</h2>
              <p id="login-description">Effettua il login per continuare</p>
            </div>
            
            <form className="login-popup-form" onSubmit={handleLoginSubmit} noValidate>
              <label className="login-popup-field">
                <span>Username</span>
                <input
                  type="text"
                  autoComplete="username"
                  value={loginForm.jid}
                  onChange={handleLoginChange('jid')}
                  placeholder="mario@conversations.im"
                  disabled={loginStatus.state === 'pending'}
                  aria-required="true"
                  aria-invalid={loginStatus.state === 'error' && !loginForm.jid}
                  aria-describedby={loginStatus.state === 'error' ? 'login-error' : undefined}
                />
              </label>
              
              <label className="login-popup-field">
                <span>Password</span>
                <input
                  type="password"
                  autoComplete="current-password"
                  value={loginForm.password}
                  onChange={handleLoginChange('password')}
                  disabled={loginStatus.state === 'pending'}
                  aria-required="true"
                  aria-invalid={loginStatus.state === 'error' && !loginForm.password}
                  aria-describedby={loginStatus.state === 'error' ? 'login-error' : undefined}
                />
              </label>
              
              <button 
                type="submit" 
                className="login-popup-button"
                disabled={loginStatus.state === 'pending'}
                aria-label={loginStatus.state === 'pending' ? 'Connessione in corso...' : 'Collega all\'account XMPP'}
              >
                {loginStatus.state === 'pending' ? 'Connessione in corso...' : 'Collegati'}
              </button>
            </form>
            
            <StatusBanner status={loginStatus} />
          </>
        )}
      </div>
    </div>
  )
}

const StatusBanner = ({ status }: { status: FormStatus }) => {
  if (status.state === 'idle') {
    return null
  }

  return (
    <div 
      className={`login-popup-status login-popup-status--${status.state}`}
      role={status.state === 'error' ? 'alert' : 'status'}
      aria-live={status.state === 'error' ? 'assertive' : 'polite'}
      id="login-error"
    >
      <p>{status.message}</p>
      {status.details && <p className="login-popup-status-details">{status.details}</p>}
    </div>
  )
}
