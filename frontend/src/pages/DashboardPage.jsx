import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { getServer, createServer, startServer, stopServer, deleteServer } from '../api/api'
import { useAuth } from '../context/AuthContext'
import ServerCard from '../components/ServerCard'
import './DashboardPage.css'

export default function DashboardPage() {
  const { username } = useAuth()
  const navigate = useNavigate()

  const [server, setServer] = useState(null)
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState(false)
  const [error, setError] = useState('')
  const [createName, setCreateName] = useState('')
  const [showCreate, setShowCreate] = useState(false)

  useEffect(() => {
    fetchServer()
  }, [])

  async function fetchServer() {
    setLoading(true)
    setError('')
    try {
      const { data } = await getServer()
      setServer(data)
    } catch {
      setServer(null)
    } finally {
      setLoading(false)
    }
  }

  async function handleCreate(e) {
    e.preventDefault()
    setActionLoading(true)
    setError('')
    try {
      const { data } = await createServer({ name: createName })
      setServer(data)
      setShowCreate(false)
      setCreateName('')
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to create server')
    } finally {
      setActionLoading(false)
    }
  }

  async function handleStart() {
    setActionLoading(true)
    setError('')
    try {
      const { data } = await startServer()
      setServer(data)
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to start server')
    } finally {
      setActionLoading(false)
    }
  }

  async function handleStop() {
    setActionLoading(true)
    setError('')
    try {
      const { data } = await stopServer()
      setServer(data)
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to stop server')
    } finally {
      setActionLoading(false)
    }
  }

  async function handleDelete() {
    if (!confirm('Are you sure you want to delete your server? This cannot be undone.')) return
    setActionLoading(true)
    setError('')
    try {
      await deleteServer()
      setServer(null)
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to delete server')
    } finally {
      setActionLoading(false)
    }
  }

  if (loading) {
    return <div className="dashboard-loading">Loading…</div>
  }

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <h1>My Server</h1>
        <p className="dashboard-subtitle">Welcome back, <strong>{username}</strong></p>
      </div>

      {error && <p className="error-msg dashboard-error">{error}</p>}

      {server ? (
        <ServerCard
          server={server}
          onStart={handleStart}
          onStop={handleStop}
          onDelete={handleDelete}
          loading={actionLoading}
        />
      ) : (
        <div className="no-server">
          <p>You don't have a Minecraft server yet.</p>
          {!showCreate ? (
            <button className="btn-primary" onClick={() => setShowCreate(true)}>
              + Create Server
            </button>
          ) : (
            <form className="create-form" onSubmit={handleCreate}>
              <input
                value={createName}
                onChange={(e) => setCreateName(e.target.value)}
                placeholder="Server name (e.g. MyWorld)"
                required
                minLength={1}
                maxLength={50}
                pattern="^[a-zA-Z0-9_\-]+$"
                title="Letters, digits, hyphens and underscores only"
                autoFocus
              />
              <div className="create-form-actions">
                <button className="btn-primary" type="submit" disabled={actionLoading}>
                  {actionLoading ? 'Creating…' : 'Create'}
                </button>
                <button className="btn-secondary" type="button" onClick={() => setShowCreate(false)}>
                  Cancel
                </button>
              </div>
            </form>
          )}
        </div>
      )}
    </div>
  )
}
