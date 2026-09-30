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
      pageRange: rangeOption === 'all' ? null : customRange,
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
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.25rem' }}>
        <div>
          <button
            onClick={onBack}
            className="btn-secondary"
            style={{ padding: '0.4rem 0.85rem', fontSize: '0.8rem', marginBottom: '0.4rem' }}
          >
            <ArrowLeft size={15} /> Back
          </button>
          <h2 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px' }}>
            Configure Print Options
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.82rem' }}>
            Document: <strong>{document.originalFilename || document.original_filename || 'document.pdf'}</strong> ({totalDocPages} pages)
          </p>
        </div>
      </div>

      <div className="options-grid">
        {/* Color Mode */}
        <div className="option-group">
          <div className="option-group-title">
            <Palette size={18} color="var(--primary)" />
            <span>Color Mode</span>
          </div>
          <div className="pill-selector">
            <button
              type="button"
              className={`pill-option ${!isColor ? 'active' : ''}`}
              onClick={() => setIsColor(false)}
            >
              Grayscale (₹2.00/pg)
            </button>
            <button
              type="button"
              className={`pill-option ${isColor ? 'active' : ''}`}
              onClick={() => setIsColor(true)}
            >
              Color (₹5.00/pg)
            </button>
          </div>
        </div>

        {/* Copies */}
        <div className="option-group">
          <div className="option-group-title">
            <Copy size={18} color="var(--primary)" />
            <span>Copies</span>
          </div>
          <div className="stepper-box">
            <button
              type="button"
              className="stepper-btn"
              onClick={() => setCopies(Math.max(1, copies - 1))}
            >
              -
            </button>
            <span className="stepper-value">{copies}</span>
            <button
              type="button"
              className="stepper-btn"
              onClick={() => setCopies(copies + 1)}
            >
              +
            </button>
          </div>
        </div>

        {/* Print Sides (Duplex) */}
        <div className="option-group">
          <div className="option-group-title">
            <Layers size={18} color="var(--primary)" />
            <span>Duplex Sides</span>
          </div>
          <div className="pill-selector">
            <button
              type="button"
              className={`pill-option ${sides === 'one-sided' ? 'active' : ''}`}
              onClick={() => setSides('one-sided')}
            >
              Single-Sided
            </button>
            <button
              type="button"
              className={`pill-option ${sides === 'two-sided-long-edge' ? 'active' : ''}`}
              onClick={() => setSides('two-sided-long-edge')}
            >
              2-Sided (Duplex)
            </button>
          </div>
        </div>

        {/* Paper Size */}
        <div className="option-group">
          <div className="option-group-title">
            <FileSpreadsheet size={18} color="var(--primary)" />
            <span>Paper Size</span>
          </div>
          <div className="pill-selector">
            {['A4', 'Letter', 'Legal'].map((size) => (
              <button
                key={size}
                type="button"
                className={`pill-option ${paperSize === size ? 'active' : ''}`}
                onClick={() => setPaperSize(size)}
              >
                {size}
              </button>
            ))}
          </div>
        </div>

        {/* Orientation */}
        <div className="option-group">
          <div className="option-group-title">
            <RotateCw size={18} color="var(--primary)" />
            <span>Orientation</span>
          </div>
          <div className="pill-selector">
            <button
              type="button"
              className={`pill-option ${orientation === 'portrait' ? 'active' : ''}`}
              onClick={() => setOrientation('portrait')}
            >
              Portrait
            </button>
            <button
              type="button"
              className={`pill-option ${orientation === 'landscape' ? 'active' : ''}`}
              onClick={() => setOrientation('landscape')}
            >
              Landscape
            </button>
          </div>
        </div>

        {/* Page Range */}
        <div className="option-group">
          <div className="option-group-title">
            <Calculator size={18} color="var(--primary)" />
            <span>Page Range</span>
          </div>
          <div className="pill-selector" style={{ marginBottom: rangeOption === 'custom' ? '0.75rem' : '0' }}>
            <button
              type="button"
              className={`pill-option ${rangeOption === 'all' ? 'active' : ''}`}
              onClick={() => setRangeOption('all')}
            >
              All Pages ({totalDocPages})
            </button>
            <button
              type="button"
              className={`pill-option ${rangeOption === 'custom' ? 'active' : ''}`}
              onClick={() => setRangeOption('custom')}
            >
              Custom Range
            </button>
          </div>
          {rangeOption === 'custom' && (
            <input
              type="text"
              placeholder="e.g. 1-3, 5"
              value={customRange}
              onChange={(e) => setCustomRange(e.target.value)}
              style={{
                width: '100%',
                padding: '0.65rem 0.85rem',
                borderRadius: '10px',
                border: '1.5px solid var(--border)',
                background: 'var(--surface-white)',
                fontSize: '0.85rem',
                color: 'var(--text-primary)',
                outline: 'none'
              }}
            />
          )}
        </div>
      </div>

      {/* Summary Box */}
      <div className="summary-card">
        <div className="summary-row">
          <span>Active Station</span>
          <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>PRINT-SERVER-001 (HP_LaserJet_400_M401dn_F36EC0)</span>
        </div>
        <div className="summary-row">
          <span>Total Sheets to Print</span>
          <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{pagesToPrint * copies} sheets</span>
        </div>
        <div className="summary-row">
          <span>Rate per Page</span>
          <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>₹{ratePerPage.toFixed(2)}</span>
        </div>
        <div className="summary-total">
          <span>Total Amount</span>
          <span className="price-tag">₹{totalAmount}</span>
        </div>
      </div>

      {error && (
        <div style={{
          background: 'var(--danger-surface)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: 'var(--danger)',
          padding: '0.85rem 1.25rem',
          borderRadius: '14px',
          marginBottom: '1.25rem',
          fontSize: '0.88rem'
        }}>
          {error}
        </div>
      )}

      <button
        className="btn-primary"
        onClick={handleProceedToPayment}
        disabled={submitting}
      >
        {submitting ? (
          <>
            <Loader2 size={18} className="animate-spin" style={{ animation: 'spin 1s linear infinite' }} />
            <span>Creating Order...</span>
          </>
        ) : (
          <>
            <span>Proceed to Payment (₹{totalAmount})</span>
            <ArrowRight size={18} />
          </>
        )}
      </button>

      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
