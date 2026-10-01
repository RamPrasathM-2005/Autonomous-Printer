import React, { useEffect, useState } from 'react';
import { Printer, RefreshCw, Server, X, Check } from 'lucide-react';
import { api } from '../api';
import logoImg from '../assets/logo.jpg';

export default function Header() {
  const [stationInfo, setStationInfo] = useState({
    name: 'HP_LaserJet_400_M401dn_F36EC0',
    state: 'READY',
    paper: 'AVAILABLE'
  });
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [showConfig, setShowConfig] = useState(false);
  const [serverUrl, setServerUrl] = useState(() => localStorage.getItem('custom_backend_url') || window.location.origin);

  const fetchStatus = async () => {
    setIsRefreshing(true);
    const data = await api.getLocalStationStatus();
    if (data) {
      setStationInfo({
        name: data.printer_name || 'HP_LaserJet_400_M401dn_F36EC0',
        state: data.printer_state || 'READY',
        paper: data.paper_state || 'AVAILABLE'
      });
    }
    setTimeout(() => setIsRefreshing(false), 500);
  };

  useEffect(() => {
    fetchStatus();
    const interval = setInterval(fetchStatus, 8000);
    return () => clearInterval(interval);
  }, []);

  const handleSaveServer = () => {
    localStorage.setItem('custom_backend_url', serverUrl.trim());
    setShowConfig(false);
    fetchStatus();
  };

  return (
    <>
      <header className="header-bar" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div className="logo-wrapper" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <img
            src={logoImg}
            alt="Logo"
            style={{ width: '38px', height: '38px', borderRadius: '10px', objectFit: 'cover' }}
            onError={(e) => { e.target.style.display = 'none'; }}
          />
          <div>
            <div className="logo-title">Autonomous Printer</div>
            <div className="logo-subtitle">Self-Service Autonomous Kiosk</div>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            onClick={() => setShowConfig(true)}
            className="btn-secondary"
            title="Configure Backend Server / Tunnel"
            style={{
              padding: '6px 12px',
              fontSize: '0.8rem',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              borderRadius: '10px'
            }}
          >
            <Server size={15} />
            <span>Server</span>
          </button>
        </div>
      </header>

      {/* Server Config Modal for Quick Tunneling */}
      {showConfig && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          width: '100vw',
          height: '100vh',
          background: 'rgba(15, 23, 42, 0.45)',
          backdropFilter: 'blur(6px)',
          zIndex: 1000,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center'
        }}>
          <div style={{
            background: 'white',
            borderRadius: '20px',
            padding: '1.75rem',
            maxWidth: '440px',
            width: '90%',
            boxShadow: '0 20px 40px rgba(0,0,0,0.15)',
            textAlign: 'left'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <div style={{ width: '32px', height: '32px', borderRadius: '8px', background: 'var(--primary-surface)', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Server size={18} />
                </div>
                <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 800 }}>Server Configuration</h3>
              </div>
              <button onClick={() => setShowConfig(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}>
                <X size={20} />
              </button>
            </div>

            <p style={{ fontSize: '0.85rem', color: '#64748b', marginBottom: '1rem' }}>
              Enter backend API tunnel or server URL for quick remote/tunnel deployment:
            </p>

            <input
              type="text"
              value={serverUrl}
              onChange={(e) => setServerUrl(e.target.value)}
              placeholder="https://your-tunnel.trycloudflare.com or http://127.0.0.1:8000"
              style={{
                width: '100%',
                padding: '10px 14px',
                borderRadius: '10px',
                border: '1.5px solid #cbd5e1',
                fontSize: '0.9rem',
                marginBottom: '1rem',
                boxSizing: 'border-box'
              }}
            />

            <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', marginBottom: '1.25rem' }}>
              <button
                type="button"
                onClick={() => setServerUrl('http://127.0.0.1:8000')}
                style={{ fontSize: '0.75rem', padding: '4px 8px', borderRadius: '6px', background: '#f1f5f9', border: '1px solid #e2e8f0', cursor: 'pointer' }}
              >
                Localhost (127.0.0.1)
              </button>
              <button
                type="button"
                onClick={() => setServerUrl('http://10.11.6.148:8000')}
                style={{ fontSize: '0.75rem', padding: '4px 8px', borderRadius: '6px', background: '#f1f5f9', border: '1px solid #e2e8f0', cursor: 'pointer' }}
              >
                Station Wi-Fi (10.11.6.148)
              </button>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <button
                onClick={() => setShowConfig(false)}
                className="btn-secondary"
                style={{ padding: '8px 16px', borderRadius: '10px' }}
              >
                Cancel
              </button>
              <button
                onClick={handleSaveServer}
                className="btn-primary"
                style={{ padding: '8px 18px', borderRadius: '10px' }}
              >
                Save & Connect
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
