import React, { useState } from 'react';
import Header from './components/Header';
import UploadStep from './components/UploadStep';
import OptionsStep from './components/OptionsStep';
import PaymentStep from './components/PaymentStep';
import OtpStep from './components/OtpStep';

export default function App() {
  const [step, setStep] = useState(1); // 1: Upload, 2: Options, 3: Payment, 4: OTP
  const [document, setDocument] = useState(null);
  const [orderData, setOrderData] = useState(null);
  const [finalData, setFinalData] = useState(null);

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
