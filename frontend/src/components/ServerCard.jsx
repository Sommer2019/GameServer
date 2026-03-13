import React from 'react'
import './ServerCard.css'

const STATUS_LABELS = {
  RUNNING: { label: 'Running', color: '#4ade80' },
  STOPPED: { label: 'Stopped', color: '#f87171' },
  CREATING: { label: 'Creating…', color: '#facc15' },
  ERROR: { label: 'Error', color: '#f87171' },
}

export default function ServerCard({ server, onStart, onStop, onDelete, loading }) {
  const statusInfo = STATUS_LABELS[server.status] || { label: server.status, color: '#9ca3af' }
  const isRunning = server.status === 'RUNNING'
  const isStopped = server.status === 'STOPPED'

  return (
    <div className="server-card">
      <div className="server-card-header">
        <h2>{server.name}</h2>
        <span className="server-status" style={{ color: statusInfo.color }}>
          ● {statusInfo.label}
        </span>
      </div>

      <div className="server-info">
        <div className="server-info-row">
          <span className="label">Address</span>
          <code>your-host:{server.port}</code>
        </div>
        <div className="server-info-row">
          <span className="label">Port</span>
          <code>{server.port}</code>
        </div>
        <div className="server-info-row">
          <span className="label">Created</span>
          <span>{new Date(server.createdAt).toLocaleString()}</span>
        </div>
      </div>

      <div className="server-card-actions">
        {isStopped && (
          <button className="btn-primary" onClick={onStart} disabled={loading}>
            ▶ Start
          </button>
        )}
        {isRunning && (
          <button className="btn-secondary" onClick={onStop} disabled={loading}>
            ■ Stop
          </button>
        )}
        <button className="btn-danger" onClick={onDelete} disabled={loading}>
          🗑 Delete
        </button>
      </div>
    </div>
  )
}
