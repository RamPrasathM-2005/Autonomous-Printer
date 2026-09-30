import React, { useEffect, useState } from 'react';
import { Printer, ShieldCheck, Terminal, UploadCloud, CheckCircle2, AlertCircle } from 'lucide-react';
import { api } from '../api';

export default function Header({ currentView, setView }) {
  const [stationInfo, setStationInfo] = useState({
    name: 'HP_LaserJet_400_M401dn_F36EC0',
    state: 'READY',
    paper: 'AVAILABLE'
  });

  useEffect(() => {
    const fetchStatus = async () => {
      const data = await api.getLocalStationStatus();
      if (data) {
        setStationInfo({
          name: data.printer_name || 'HP_LaserJet_400_M401dn_F36EC0',
          state: data.printer_state || 'READY',
          paper: data.paper_state || 'AVAILABLE'
        });
      }
    };
    fetchStatus();
    const interval = setInterval(fetchStatus, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <header className="header-bar">
      <div className="logo-wrapper" onClick={() => setView('flow')} style={{ cursor: 'pointer' }}>
        <div className="logo-icon">
          <Printer size={22} strokeWidth={2.5} />
        </div>
        <div>
          <span className="logo-text">SmartPrint</span>
          <span className="logo-tag">Hub React</span>
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
          Kiosk Terminal
        </button>
      </nav>

      <div className="station-badge">
        <span className="pulsing-dot" />
        <span>{stationInfo.name}</span>
        <span style={{ opacity: 0.7, fontSize: '0.75rem' }}>({stationInfo.state})</span>
      </div>
    </header>
  );
}
