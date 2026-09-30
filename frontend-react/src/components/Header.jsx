import React, { useEffect, useState } from 'react';
import { Printer, RefreshCw, UploadCloud, Terminal } from 'lucide-react';
import { api } from '../api';

export default function Header({ currentView, setView }) {
  const [stationInfo, setStationInfo] = useState({
    name: 'HP_LaserJet_400_M401dn_F36EC0',
    state: 'READY',
    paper: 'AVAILABLE'
  });
  const [isRefreshing, setIsRefreshing] = useState(false);

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
    const interval = setInterval(fetchStatus, 6000);
    return () => clearInterval(interval);
  }, []);

  return (
    <header className="header-bar">
      <div className="logo-wrapper" onClick={() => setView('flow')} style={{ cursor: 'pointer' }}>
        <div className="logo-icon">
          <Printer size={22} strokeWidth={2.4} />
        </div>
        <div>
          <div className="logo-title">QwikPrint</div>
          <div className="logo-subtitle">Autonomous Self-Service Kiosk</div>
        </div>
      </div>

      <nav className="nav-tabs">
        <button
          className={`nav-tab ${currentView === 'flow' ? 'active' : ''}`}
          onClick={() => setView('flow')}
        >
          <UploadCloud size={16} />
          Print Order
        </button>
        <button
          className={`nav-tab ${currentView === 'kiosk' ? 'active' : ''}`}
          onClick={() => setView('kiosk')}
        >
          <Terminal size={16} />
          Station Terminal
        </button>
      </nav>

      <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
        <div className="station-badge">
          <span className="pulsing-dot" />
          <span>{stationInfo.name}</span>
          <span style={{ opacity: 0.7, fontSize: '0.75rem' }}>({stationInfo.state})</span>
        </div>
        <button
          onClick={fetchStatus}
          style={{
            background: 'transparent',
            border: 'none',
            color: 'var(--text-secondary)',
            cursor: 'pointer',
            padding: '4px',
            display: 'flex',
            alignItems: 'center'
          }}
          title="Refresh Station Status"
        >
          <RefreshCw size={17} className={isRefreshing ? 'animate-spin' : ''} style={{ animation: isRefreshing ? 'spin 1s linear infinite' : 'none' }} />
        </button>
      </div>
    </header>
  );
}
