import React, { useState } from 'react';
import { ArrowLeft, ArrowRight, Palette, Copy, Layers, FileSpreadsheet, RotateCw, Calculator, Loader2 } from 'lucide-react';
import { api } from '../api';

export default function OptionsStep({ document, onBack, onNext }) {
  const [isColor, setIsColor] = useState(false);
  const [copies, setCopies] = useState(1);
  const [sides, setSides] = useState('one-sided');
  const [paperSize, setPaperSize] = useState('A4');
  const [orientation, setOrientation] = useState('portrait');
  const [rangeOption, setRangeOption] = useState('all');
  const [customRange, setCustomRange] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const totalDocPages = document.pages || document.page_count || 1;

  // Calculate pages based on range
  const calculatePages = () => {
    if (rangeOption === 'all') return totalDocPages;
    if (rangeOption === 'odd') return Math.ceil(totalDocPages / 2);
    if (rangeOption === 'even') return Math.floor(totalDocPages / 2);
    if (rangeOption === 'custom' && customRange.trim()) {
      try {
        let count = 0;
        const parts = customRange.split(',');
        for (let part of parts) {
          part = part.trim();
          if (part.includes('-')) {
            const [start, end] = part.split('-').map(Number);
            if (!isNaN(start) && !isNaN(end) && end >= start) {
              count += Math.max(0, Math.min(end, totalDocPages) - Math.max(1, start) + 1);
            }
          } else {
            const p = Number(part);
            if (!isNaN(p) && p >= 1 && p <= totalDocPages) count++;
          }
        }
        return count > 0 ? count : totalDocPages;
      } catch {
        return totalDocPages;
      }
    }
    return totalDocPages;
  };

  const pagesToPrint = calculatePages();
  const ratePerPage = isColor ? 5.0 : 2.0;
  const totalAmount = (pagesToPrint * copies * ratePerPage).toFixed(2);

  const handleProceedToPayment = async () => {
    setSubmitting(true);
    setError(null);

    const printSettings = {
      colour: isColor,
      copies: copies,
      sides: sides,
      paperSize: paperSize,
      paper_size: paperSize,
      orientation: orientation,
      pageRange: rangeOption === 'all' ? null : (rangeOption === 'custom' ? customRange : rangeOption),
    };

    try {
      const order = await api.createOrder({
        documentId: document.id || document.documentId,
        printServerId: 'PRINT-SERVER-001',
        printSettings: printSettings,
      });

      onNext({
        order,
        document,
        printSettings,
        totalAmount,
        pagesToPrint,
      });
    } catch (err) {
      setError(err.message || 'Failed to initialize print order');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '2rem' }}>
        <div>
          <button
            onClick={onBack}
            className="btn-secondary"
            style={{ padding: '0.4rem 0.9rem', fontSize: '0.85rem', marginBottom: '0.5rem' }}
          >
            <ArrowLeft size={16} /> Back
          </button>
          <h1 style={{ fontSize: '2rem', fontWeight: 800 }}>Configure Print Job</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>
            Document: <strong>{document.originalFilename || document.original_filename || 'Document'}</strong> ({totalDocPages} pages)
          </p>
        </div>
      </div>

      {error && (
        <div style={{
          background: 'rgba(239, 68, 68, 0.1)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: '#f87171',
          padding: '0.9rem 1.25rem',
          borderRadius: 'var(--radius-md)',
          marginBottom: '1.5rem'
        }}>
          {error}
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1.8fr 1.2fr', gap: '2rem' }}>
        {/* Left Column: Options */}
        <div>
          {/* Color Mode */}
          <div style={{ marginBottom: '1.75rem' }}>
            <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.75rem', fontSize: '0.95rem' }}>
              Color Mode
            </label>
            <div className="options-grid" style={{ gridTemplateColumns: '1fr 1fr', margin: 0 }}>
              <div
                className={`option-box ${!isColor ? 'selected' : ''}`}
                onClick={() => setIsColor(false)}
              >
                <div style={{ fontWeight: 700, fontSize: '1rem', marginBottom: '0.25rem' }}>Black & White</div>
                <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>₹2.00 / page</div>
              </div>
              <div
                className={`option-box ${isColor ? 'selected' : ''}`}
                onClick={() => setIsColor(true)}
              >
                <div style={{ fontWeight: 700, fontSize: '1rem', marginBottom: '0.25rem', color: '#ec4899' }}>Full Color</div>
                <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>₹5.00 / page</div>
              </div>
            </div>
          </div>

          {/* Copies & Sidedness */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '1.75rem' }}>
            <div>
              <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.75rem', fontSize: '0.95rem' }}>
                Number of Copies
              </label>
              <div className="counter-box">
                <button
                  type="button"
                  className="counter-btn"
                  onClick={() => setCopies(Math.max(1, copies - 1))}
                >
                  -
                </button>
                <span className="counter-value">{copies}</span>
                <button
                  type="button"
                  className="counter-btn"
                  onClick={() => setCopies(Math.min(50, copies + 1))}
                >
                  +
                </button>
              </div>
            </div>

            <div>
              <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.75rem', fontSize: '0.95rem' }}>
                Sides / Duplex
              </label>
              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button
                  type="button"
                  className={`btn-secondary ${sides === 'one-sided' ? 'selected' : ''}`}
                  style={{
                    flex: 1,
                    borderColor: sides === 'one-sided' ? 'var(--accent-primary)' : 'var(--border-subtle)',
                    background: sides === 'one-sided' ? 'rgba(99, 102, 241, 0.15)' : 'var(--bg-secondary)'
                  }}
                  onClick={() => setSides('one-sided')}
                >
                  1-Sided
                </button>
                <button
                  type="button"
                  className={`btn-secondary ${sides !== 'one-sided' ? 'selected' : ''}`}
                  style={{
                    flex: 1,
                    borderColor: sides !== 'one-sided' ? 'var(--accent-primary)' : 'var(--border-subtle)',
                    background: sides !== 'one-sided' ? 'rgba(99, 102, 241, 0.15)' : 'var(--bg-secondary)'
                  }}
                  onClick={() => setSides('two-sided-long-edge')}
                >
                  2-Sided
                </button>
              </div>
            </div>
          </div>

          {/* Paper Size & Orientation */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '1.75rem' }}>
            <div>
              <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.75rem', fontSize: '0.95rem' }}>
                Paper Size
              </label>
              <select
                value={paperSize}
                onChange={(e) => setPaperSize(e.target.value)}
                style={{
                  width: '100%',
                  padding: '0.85rem',
                  borderRadius: 'var(--radius-md)',
                  background: 'var(--bg-secondary)',
                  border: '1px solid var(--border-subtle)',
                  color: 'var(--text-main)',
                  fontWeight: 600,
                  fontSize: '0.95rem'
                }}
              >
                <option value="A4">A4 (Standard 210 × 297 mm)</option>
                <option value="Letter">Letter (8.5 × 11 in)</option>
                <option value="Legal">Legal (8.5 × 14 in)</option>
              </select>
            </div>

            <div>
              <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.75rem', fontSize: '0.95rem' }}>
                Orientation
              </label>
              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button
                  type="button"
                  className="btn-secondary"
                  style={{
                    flex: 1,
                    borderColor: orientation === 'portrait' ? 'var(--accent-primary)' : 'var(--border-subtle)',
                    background: orientation === 'portrait' ? 'rgba(99, 102, 241, 0.15)' : 'var(--bg-secondary)'
                  }}
                  onClick={() => setOrientation('portrait')}
                >
                  Portrait
                </button>
                <button
                  type="button"
                  className="btn-secondary"
                  style={{
                    flex: 1,
                    borderColor: orientation === 'landscape' ? 'var(--accent-primary)' : 'var(--border-subtle)',
                    background: orientation === 'landscape' ? 'rgba(99, 102, 241, 0.15)' : 'var(--bg-secondary)'
                  }}
                  onClick={() => setOrientation('landscape')}
                >
                  Landscape
                </button>
              </div>
            </div>
          </div>

          {/* Page Range */}
          <div>
            <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.75rem', fontSize: '0.95rem' }}>
              Pages to Print
            </label>
            <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '0.75rem' }}>
              {['all', 'odd', 'even', 'custom'].map((opt) => (
                <button
                  key={opt}
                  type="button"
                  className="btn-secondary"
                  style={{
                    flex: 1,
                    textTransform: 'capitalize',
                    borderColor: rangeOption === opt ? 'var(--accent-primary)' : 'var(--border-subtle)',
                    background: rangeOption === opt ? 'rgba(99, 102, 241, 0.15)' : 'var(--bg-secondary)'
                  }}
                  onClick={() => setRangeOption(opt)}
                >
                  {opt}
                </button>
              ))}
            </div>

            {rangeOption === 'custom' && (
              <input
                type="text"
                placeholder="e.g. 1-3, 5, 8"
                value={customRange}
                onChange={(e) => setCustomRange(e.target.value)}
                style={{
                  width: '100%',
                  padding: '0.85rem',
                  borderRadius: 'var(--radius-md)',
                  background: 'var(--bg-secondary)',
                  border: '1px solid var(--border-subtle)',
                  color: 'var(--text-main)',
                  fontWeight: 600
                }}
              />
            )}
          </div>
        </div>

        {/* Right Column: Price Breakdown Panel */}
        <div>
          <div className="summary-panel">
            <h3 style={{ fontSize: '1.2rem', fontWeight: 800, marginBottom: '1.25rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Calculator size={20} color="#818cf8" />
              Order Summary
            </h3>

            <div className="summary-row">
              <span>Document</span>
              <span style={{ color: 'var(--text-main)', fontWeight: 600 }}>
                {document.originalFilename || document.original_filename}
              </span>
            </div>

            <div className="summary-row">
              <span>Page Count</span>
              <span style={{ color: 'var(--text-main)', fontWeight: 600 }}>
                {pagesToPrint} of {totalDocPages} pages
              </span>
            </div>

            <div className="summary-row">
              <span>Copies</span>
              <span style={{ color: 'var(--text-main)', fontWeight: 600 }}>{copies}</span>
            </div>

            <div className="summary-row">
              <span>Print Type</span>
              <span style={{ color: isColor ? '#ec4899' : 'var(--text-main)', fontWeight: 600 }}>
                {isColor ? 'Color (₹5/pg)' : 'B&W (₹2/pg)'}
              </span>
            </div>

            <div className="summary-row">
              <span>Paper & Feed</span>
              <span style={{ color: 'var(--text-main)', fontWeight: 600 }}>
                {paperSize} • {sides === 'one-sided' ? '1-Sided' : '2-Sided'}
              </span>
            </div>

            <div className="summary-total">
              <div>
                <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)', display: 'block' }}>Total Payable</span>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>Inclusive of all taxes</span>
              </div>
              <div className="total-amount">₹{totalAmount}</div>
            </div>

            <div style={{ marginTop: '1.75rem' }}>
              <button
                className="btn-primary"
                onClick={handleProceedToPayment}
                disabled={submitting}
              >
                {submitting ? (
                  <>
                    <Loader2 size={18} style={{ animation: 'spin 1s linear infinite' }} />
                    <span>Creating Order...</span>
                  </>
                ) : (
                  <>
                    <span>Proceed to Payment</span>
                    <ArrowRight size={18} />
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
