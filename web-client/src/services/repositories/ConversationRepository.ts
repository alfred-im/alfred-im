import { getDB } from '../conversations-db'
import type { Conversation } from '../conversations-db'

/**
 * Repository per operazioni CRUD su conversazioni
 * Garantisce transazioni atomiche e gestione errori centralizzata
 */
export class ConversationRepository {
  /**
   * Salva multiple conversazioni in una transazione atomica
   * Mantiene unreadCount esistente se presente
   */
  async saveAll(conversations: Conversation[]): Promise<void> {
    if (conversations.length === 0) return

    const db = await getDB()
    const tx = db.transaction('conversations', 'readwrite')

    try {
      for (const conv of conversations) {
        // Merge con conversazione esistente
        const existing = await tx.store.get(conv.jid)
        if (existing) {
          // Mantieni unreadCount esistente
          conv.unreadCount = existing.unreadCount
        }
        await tx.store.put(conv)
      }
      await tx.done
    } catch (error) {
      // Transaction automaticamente abortita in caso di errore
      console.error('Errore nel salvataggio conversazioni:', error)
      throw new Error('Impossibile salvare le conversazioni')
    }
  }

  /**
   * Recupera tutte le conversazioni ordinate per data
   */
  async getAll(): Promise<Conversation[]> {
    const db = await getDB()
    const tx = db.transaction('conversations', 'readonly')
    const conversations = await tx.store.getAll()
    await tx.done

    // Normalizza Date
    const normalized = conversations.map(conv => ({
      ...conv,
      lastMessage: {
        ...conv.lastMessage,
        timestamp: conv.lastMessage.timestamp instanceof Date 
          ? conv.lastMessage.timestamp 
          : new Date(conv.lastMessage.timestamp)
      },
      updatedAt: conv.updatedAt instanceof Date 
        ? conv.updatedAt 
        : new Date(conv.updatedAt)
    }))

    // Ordina per data (più recenti prima)
    return normalized.sort(
      (a, b) => b.lastMessage.timestamp.getTime() - a.lastMessage.timestamp.getTime()
    )
  }

  /**
   * Aggiorna una conversazione esistente o la crea se non esiste
   * Operazione atomica
   */
  async update(jid: string, updates: Partial<Conversation>): Promise<void> {
    const db = await getDB()
    const tx = db.transaction('conversations', 'readwrite')

    try {
      const existing = await tx.store.get(jid)

      if (existing) {
        // Normalizza timestamps
        const existingTimestamp = existing.lastMessage.timestamp instanceof Date
          ? existing.lastMessage.timestamp
          : new Date(existing.lastMessage.timestamp)
        
        const updatesTimestamp = updates.lastMessage?.timestamp
          ? (updates.lastMessage.timestamp instanceof Date
              ? updates.lastMessage.timestamp
              : new Date(updates.lastMessage.timestamp))
          : existingTimestamp
        
        const updatedAt = updates.lastMessage?.timestamp ? updatesTimestamp : existingTimestamp
        
        await tx.store.put({ 
          ...existing, 
          ...updates, 
          updatedAt,
          lastMessage: updates.lastMessage 
            ? { ...updates.lastMessage, timestamp: updatesTimestamp }
            : { ...existing.lastMessage, timestamp: existingTimestamp }
        })
      } else if (updates.jid) {
        // Crea nuova conversazione
        const timestamp = updates.lastMessage!.timestamp instanceof Date
          ? updates.lastMessage!.timestamp
          : new Date(updates.lastMessage!.timestamp)
        
        await tx.store.put({
          jid: updates.jid,
          lastMessage: {
            ...updates.lastMessage!,
            timestamp
          },
          unreadCount: updates.unreadCount ?? 0,
          displayName: updates.displayName,
          avatarData: updates.avatarData,
          avatarType: updates.avatarType,
          updatedAt: timestamp,
        })
      }

      await tx.done
    } catch (error) {
      console.error('Errore nell\'aggiornamento conversazione:', error)
      throw new Error('Impossibile aggiornare la conversazione')
    }
  }

  /**
   * Elimina una conversazione
   */
  async delete(jid: string): Promise<void> {
    const db = await getDB()
    const tx = db.transaction('conversations', 'readwrite')
    
    try {
      await tx.store.delete(jid)
      await tx.done
    } catch (error) {
      console.error('Errore nell\'eliminazione conversazione:', error)
      throw new Error('Impossibile eliminare la conversazione')
    }
  }

  /**
   * Elimina multiple conversazioni in transazione atomica
   */
  async deleteMany(jids: string[]): Promise<void> {
    if (jids.length === 0) return
    
    const db = await getDB()
    const tx = db.transaction('conversations', 'readwrite')
    
    try {
      for (const jid of jids) {
        await tx.store.delete(jid)
      }
      await tx.done
    } catch (error) {
      console.error('Errore nell\'eliminazione conversazioni:', error)
      throw new Error('Impossibile eliminare le conversazioni')
    }
  }

  /**
   * Svuota tutte le conversazioni
   */
  async clear(): Promise<void> {
    const db = await getDB()
    const tx = db.transaction('conversations', 'readwrite')
    
    try {
      await tx.store.clear()
      await tx.done
    } catch (error) {
      console.error('Errore nella cancellazione conversazioni:', error)
      throw new Error('Impossibile cancellare le conversazioni')
    }
  }

  /**
   * Recupera una singola conversazione per JID
   */
  async getByJid(jid: string): Promise<Conversation | null> {
    const db = await getDB()
    const tx = db.transaction('conversations', 'readonly')
    const conv = await tx.store.get(jid)
    await tx.done

    if (!conv) return null

    // Normalizza Date
    return {
      ...conv,
      lastMessage: {
        ...conv.lastMessage,
        timestamp: conv.lastMessage.timestamp instanceof Date 
          ? conv.lastMessage.timestamp 
          : new Date(conv.lastMessage.timestamp)
      },
      updatedAt: conv.updatedAt instanceof Date 
        ? conv.updatedAt 
        : new Date(conv.updatedAt)
    }
  }

  /**
   * Marca una conversazione come letta (azzera unreadCount)
   */
  async markAsRead(jid: string): Promise<void> {
    await this.update(jid, { unreadCount: 0 })
  }

  /**
   * Incrementa il contatore non letti di una conversazione
   */
  async incrementUnread(jid: string): Promise<void> {
    const db = await getDB()
    const tx = db.transaction('conversations', 'readwrite')

    try {
      const existing = await tx.store.get(jid)
      if (existing) {
        await tx.store.put({
          ...existing,
          unreadCount: existing.unreadCount + 1,
        })
      }
      await tx.done
    } catch (error) {
      console.error('Errore nell\'incremento unread:', error)
      throw new Error('Impossibile aggiornare il contatore non letti')
    }
  }
}
