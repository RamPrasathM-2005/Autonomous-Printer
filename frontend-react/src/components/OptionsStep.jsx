import React, { useState } from 'react';
import { ArrowLeft, ArrowRight, Palette, Copy, Layers, FileSpreadsheet, RotateCw, Calculator, Loader2, Eye, FileText } from 'lucide-react';
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
      <div style={{ marginBottom: '1.25rem' }}>
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
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
          Select color mode, sides, copies, and orientation for your document.
        </p>
      </div>

      {/* Active Document Header Card - Matches Flutter _buildDocumentHeaderCard() */}
      <div className="card-white" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '1rem 1.25rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
          <div className="doc-icon-box">
            <FileText size={22} />
          </div>
          <div>
            <div style={{ fontWeight: 800, fontSize: '0.98rem', color: 'var(--text-primary)' }}>
              {document.originalFilename || document.original_filename || 'document.pdf'}
            </div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)', display: 'flex', gap: '8px', marginTop: '2px' }}>
              <span>{totalDocPages} Pages</span>
              <span>•</span>
              <span>Standard Print Ready</span>
            </div>
          </div>
        </div>
        <div style={{
          background: 'var(--primary-surface)',
          color: 'var(--primary)',
          padding: '4px 10px',
          borderRadius: '8px',
          fontSize: '0.75rem',
          fontWeight: 700
        }}>
          Active Document
        </div>
      </div>

      {/* Document Sheet Visualizer Card - Matches Flutter _buildDocumentPreviewCard() */}
      <div className="card-white" style={{ textAlign: 'center', padding: '1.5rem 1rem' }}>
        <div style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.8px', marginBottom: '1rem' }}>
          Page Layout Preview
        </div>
        
        {/* Visual Sheet Preview Box */}
        <div style={{
          margin: '0 auto',
          width: orientation === 'portrait' ? '120px' : '160px',
          height: orientation === 'portrait' ? '160px' : '120px',
          background: '#ffffff',
          borderRadius: '10px',
          border: '2px solid #cbd5e1',
          boxShadow: '0 8px 20px rgba(0, 0, 0, 0.08)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '6px',
          transition: 'all 0.25s ease',
          position: 'relative'
        }}>
          <div style={{
            position: 'absolute',
            top: '6px',
            right: '6px',
            fontSize: '0.65rem',
            fontWeight: 800,
            background: isColor ? '#ec4899' : '#64748b',
            color: 'white',
            padding: '2px 5px',
            borderRadius: '4px'
          }}>
            {isColor ? 'COLOR' : 'B&W'}
          </div>
          <FileText size={28} color={isColor ? 'var(--primary)' : '#64748b'} />
          <div style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-primary)' }}>
            {paperSize}
          </div>
          <div style={{ fontSize: '0.65rem', color: 'var(--text-secondary)', textTransform: 'capitalize' }}>
            {orientation}
          </div>
        </div>
      </div>

      {/* Options Grid */}
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
            <span>Sides</span>
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

      {/* Invoice Summary Card */}
      <div className="summary-card">
        <div className="summary-row">
          <span>Sheets to Print</span>
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
