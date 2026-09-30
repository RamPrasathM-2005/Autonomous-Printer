import React, { useEffect, useState } from 'react';
import { Printer, RefreshCw, Smartphone, Download } from 'lucide-react';
import { api } from '../api';

export default function Header() {
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
    const interval = setInterval(fetchStatus, 8000);
    return () => clearInterval(interval);
  }, []);

  return (
    <header className="header-bar">
      <div className="logo-wrapper">
        <div className="logo-icon">
          <Printer size={22} strokeWidth={2.4} />
        </div>
        <div>
          <div className="logo-title">Autonomous Printer</div>
          <div className="logo-subtitle">Self-Service Autonomous Kiosk</div>
        </div>
      </div>
    </header>
  );
}
