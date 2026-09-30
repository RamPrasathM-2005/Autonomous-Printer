import React, { useState, useEffect } from 'react';
import Header from './components/Header';
import UploadStep from './components/UploadStep';
import OptionsStep from './components/OptionsStep';
import PaymentStep from './components/PaymentStep';
import OtpStep from './components/OtpStep';
import { Smartphone, Download, X } from 'lucide-react';

export default function App() {
  const [step, setStep] = useState(1); // 1: Upload, 2: Options, 3: Payment, 4: OTP
  const [document, setDocument] = useState(null);
  const [orderData, setOrderData] = useState(null);
  const [finalData, setFinalData] = useState(null);
  const [showAppBanner, setShowAppBanner] = useState(true);

  // If user scanned QR code with mobile browser, check if app is installed
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const isScan = params.get('scan') === '1' || params.get('qr') === '1';
    const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);

    if (isScan && isMobile) {
      // Attempt custom scheme to open app if installed
      const iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = 'autonomousprinter://open';
      document.body.appendChild(iframe);
      setTimeout(() => {
        try { document.body.removeChild(iframe); } catch (_) {}
      }, 1500);
    }
  }, []);

  const handleDocumentUploaded = (doc) => {
    setDocument(doc);
    setStep(2);
  };

  const handleOptionsConfigured = (data) => {
    setOrderData(data);
    setStep(3);
  };

  const handlePaymentCompleted = (data) => {
    setFinalData(data);
    setStep(4);
  };

  const handleReset = () => {
    setDocument(null);
    setOrderData(null);
    setFinalData(null);
    setStep(1);
  };

  return (
    <div className="app-container">
      <Header />

      {/* Mobile App Prompt Banner */}
      {showAppBanner && (
        <div className="app-download-banner">
          <div className="banner-content">
            <Smartphone size={16} color="#4f46e5" />
            <span>
              <strong>Autonomous Printer App:</strong> Have the app installed or prefer a native experience?
            </span>
            <a
              href="/downloads/autonomous-printer.apk"
              download="autonomous-printer.apk"
              className="banner-apk-link"
            >
              <Download size={13} />
              <span>Download APK</span>
            </a>
          </div>
          <button
            onClick={() => setShowAppBanner(false)}
            className="banner-close-btn"
            title="Dismiss"
          >
            <X size={15} />
          </button>
        </div>
      )}

      <main className="main-content">
        {/* Step Progress Bar - Exactly matches Flutter WorkflowStepper */}
        <div className="steps-wrapper">
          <div className={`step-item ${step === 1 ? 'active' : step > 1 ? 'completed' : ''}`}>
            <div className="step-circle">{step > 1 ? '✓' : '1'}</div>
            <span>Upload</span>
          </div>
          <div className={`step-line ${step > 1 ? 'filled' : ''}`} />
          <div className={`step-item ${step === 2 ? 'active' : step > 2 ? 'completed' : ''}`}>
            <div className="step-circle">{step > 2 ? '✓' : '2'}</div>
            <span>Options</span>
          </div>
          <div className={`step-line ${step > 2 ? 'filled' : ''}`} />
          <div className={`step-item ${step === 3 ? 'active' : step > 3 ? 'completed' : ''}`}>
            <div className="step-circle">{step > 3 ? '✓' : '3'}</div>
            <span>Payment</span>
          </div>
          <div className={`step-line ${step > 3 ? 'filled' : ''}`} />
          <div className={`step-item ${step === 4 ? 'active' : ''}`}>
            <div className="step-circle">4</div>
            <span>Release</span>
          </div>
        </div>

        {/* Step Views */}
        {step === 1 && <UploadStep onNext={handleDocumentUploaded} />}
        {step === 2 && (
          <OptionsStep
            document={document}
            onBack={() => setStep(1)}
            onNext={handleOptionsConfigured}
          />
        )}
        {step === 3 && (
          <PaymentStep
            orderData={orderData}
            onBack={() => setStep(2)}
            onNext={handlePaymentCompleted}
          />
        )}
        {step === 4 && (
          <OtpStep
            finalData={finalData}
            onReset={handleReset}
          />
        )}
      </main>
    </div>
  );
}
