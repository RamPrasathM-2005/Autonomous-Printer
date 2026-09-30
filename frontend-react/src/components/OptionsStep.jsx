import React, { useState } from 'react';
import { ArrowLeft, ArrowRight, Palette, Copy, Layers, FileSpreadsheet, RotateCw, Calculator, Loader2, FileText, Check } from 'lucide-react';
import { api } from '../api';

export default function OptionsStep({ documents = [], onBack, onNext }) {
  // Normalize documents list
  const docList = Array.isArray(documents) && documents.length > 0 ? documents : [documents];

  // Store configuration per document
  const [configs, setConfigs] = useState(() => {
    return docList.map(doc => ({
      document: doc,
      copies: 1,
      isColor: false,
      sides: 'one-sided',
      paperSize: 'A4',
      printQuality: 'Standard',
      rangeOption: 'all',
      customRange: '',
      orientation: 'portrait',
    }));
  });

  const [activeDocIndex, setActiveDocIndex] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const activeConfig = configs[activeDocIndex] || configs[0];
  const activeDoc = activeConfig.document;
  const totalDocPages = activeDoc.pages || activeDoc.page_count || 1;

  // Calculate pages for a given configuration
  const calculatePages = (config) => {
    const total = config.document.pages || config.document.page_count || 1;
    if (config.rangeOption === 'all') return total;
    if (config.rangeOption === 'odd') return Math.ceil(total / 2);
    if (config.rangeOption === 'even') return Math.floor(total / 2);
    if (config.rangeOption === 'custom' && config.customRange.trim()) {
      try {
        let count = 0;
        const parts = config.customRange.split(',');
        for (let part of parts) {
          part = part.trim();
          if (part.includes('-')) {
            const [start, end] = part.split('-').map(Number);
            if (!isNaN(start) && !isNaN(end) && end >= start) {
              count += Math.max(0, Math.min(end, total) - Math.max(1, start) + 1);
            }
          } else {
            const p = Number(part);
            if (!isNaN(p) && p >= 1 && p <= total) count++;
          }
        }
        return count > 0 ? count : total;
      } catch {
        return total;
      }
    }
    return total;
  };

  const updateActiveConfig = (updates) => {
    setConfigs(prev => {
      const copy = [...prev];
      copy[activeDocIndex] = { ...copy[activeDocIndex], ...updates };
      return copy;
    });
  };

  // Pricing calculations
  const calculateDocCost = (config) => {
    const pages = calculatePages(config);
    const rate = config.isColor ? 5.0 : 2.0;
    return pages * config.copies * rate;
  };

  const totalCalculatedCost = configs.reduce((sum, c) => sum + calculateDocCost(c), 0);
  const totalPagesToPrint = configs.reduce((sum, c) => sum + (calculatePages(c) * c.copies), 0);

  const handleProceedToPayment = async () => {
    setSubmitting(true);
    setError(null);

    try {
      const firstConfig = configs[0];
      const primaryDoc = firstConfig.document;

      const primaryPrintSettings = {
        colour: firstConfig.isColor,
        copies: firstConfig.copies,
        sides: firstConfig.sides,
        paperSize: firstConfig.paperSize,
        paper_size: firstConfig.paperSize,
        orientation: firstConfig.orientation,
        print_quality: firstConfig.printQuality,
        pageRange: firstConfig.rangeOption === 'all' ? null : firstConfig.customRange,
        page_range: firstConfig.rangeOption === 'all' ? null : firstConfig.customRange,
      };

      const items = configs.map(c => ({
        document_id: c.document.id || c.document.document_id || c.document.documentId,
        copies: c.copies,
        colour: c.isColor,
        sides: c.sides,
        paper_size: c.paperSize,
        page_range: c.rangeOption === 'all' ? null : c.customRange,
      }));

      const order = await api.createOrder({
        documentId: primaryDoc.id || primaryDoc.document_id || primaryDoc.documentId,
        printServerId: 'PRINT-SERVER-001',
        printSettings: primaryPrintSettings,
        items: items
      });

      onNext({
        order,
        documents: docList,
        configs: configs,
        totalAmount: totalCalculatedCost.toFixed(2),
        pagesToPrint: totalPagesToPrint,
        printSettings: primaryPrintSettings
      });
    } catch (err) {
      setError(err.message || 'Failed to initialize order. Please check inputs and retry.');
    } finally {
      setSubmitting(false);
    }
  };

  const activePages = calculatePages(activeConfig);
  const activeRate = activeConfig.isColor ? 5.0 : 2.0;
  const activeDocCost = (activePages * activeConfig.copies * activeRate).toFixed(2);

  return (
    <div style={{ maxWidth: '720px', margin: '0 auto' }}>
      
      {/* Top Header & Back Navigation */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.25rem' }}>
        <button
          onClick={onBack}
          className="btn-secondary"
          style={{ padding: '0.4rem 0.85rem', fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <ArrowLeft size={15} /> Back
        </button>
        <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-muted)' }}>
          Step 2 of 4
        </span>
      </div>

      <div style={{ marginBottom: '1.25rem' }}>
        <h2 style={{ fontSize: '1.45rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px', margin: 0 }}>
          Configure Print Options
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', margin: '0.2rem 0 0 0' }}>
          Customize color, copies, duplex, paper size, and page ranges.
        </p>
      </div>

      {/* Multi-Document Tabs (Matches Flutter _buildDocumentTabBar) */}
      {docList.length > 1 && (
        <div style={{
          display: 'flex',
          gap: '8px',
          overflowX: 'auto',
          paddingBottom: '8px',
          marginBottom: '1.25rem'
        }}>
          {configs.map((c, idx) => {
            const isSelected = idx === activeDocIndex;
            return (
              <button
                key={idx}
                type="button"
                onClick={() => setActiveDocIndex(idx)}
                style={{
                  background: isSelected ? 'var(--primary)' : 'var(--surface-white)',
                  color: isSelected ? 'white' : 'var(--text-secondary)',
                  border: `1.5px solid ${isSelected ? 'var(--primary)' : 'var(--border)'}`,
                  borderRadius: '14px',
                  padding: '0.55rem 1rem',
                  fontSize: '0.82rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  whiteSpace: 'nowrap',
                  boxShadow: isSelected ? '0 4px 12px rgba(79, 70, 229, 0.25)' : 'none',
                  transition: 'all 0.15s ease'
                }}
              >
                <FileText size={14} />
                <span>{c.document.original_filename || c.document.originalFilename || `Doc ${idx + 1}`}</span>
              </button>
            );
          })}
        </div>
      )}

      {/* Active Document Info Card */}
      <div className="card-white" style={{ display: 'flex', alignItems: 'center', gap: '0.85rem', padding: '0.85rem 1.15rem', marginBottom: '1.25rem' }}>
        <div style={{
          width: '42px',
          height: '42px',
          borderRadius: '12px',
          background: 'var(--primary-surface)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: 'var(--primary)',
          flexShrink: 0
        }}>
          <FileText size={20} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 800, fontSize: '0.92rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {activeDoc.original_filename || activeDoc.originalFilename || 'Document'}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)', marginTop: '2px' }}>
            Total Pages: <strong>{totalDocPages}</strong> &bull; Selected to print: <strong>{activePages} page(s)</strong>
          </div>
        </div>
      </div>

      {/* Color Mode Segmented Toggle - Exactly matches Flutter */}
      <div className="card-white" style={{ padding: '1.25rem', marginBottom: '1.15rem' }}>
        <div style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.85rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
          <Palette size={18} color="var(--primary)" />
          <span>Color Mode</span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
          <button
            type="button"
            onClick={() => updateActiveConfig({ isColor: false })}
            style={{
              padding: '0.9rem',
              borderRadius: '14px',
              border: `2px solid ${!activeConfig.isColor ? 'var(--primary)' : 'var(--border)'}`,
              background: !activeConfig.isColor ? 'var(--primary-surface)' : 'var(--surface-white)',
              color: !activeConfig.isColor ? 'var(--primary)' : 'var(--text-primary)',
              cursor: 'pointer',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '4px',
              transition: 'all 0.15s ease'
            }}
          >
            <span style={{ fontWeight: 800, fontSize: '0.95rem' }}>Black & White</span>
            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>₹2.00 / page</span>
          </button>

          <button
            type="button"
            onClick={() => updateActiveConfig({ isColor: true })}
            style={{
              padding: '0.9rem',
              borderRadius: '14px',
              border: `2px solid ${activeConfig.isColor ? 'var(--primary)' : 'var(--border)'}`,
              background: activeConfig.isColor ? 'var(--primary-surface)' : 'var(--surface-white)',
              color: activeConfig.isColor ? 'var(--primary)' : 'var(--text-primary)',
              cursor: 'pointer',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '4px',
              transition: 'all 0.15s ease'
            }}
          >
            <span style={{ fontWeight: 800, fontSize: '0.95rem' }}>Full Color</span>
            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>₹5.00 / page</span>
          </button>
        </div>
      </div>

      {/* Copies & Print Quality Card */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '1.15rem' }}>
        
        {/* Copies Stepper */}
        <div className="card-white" style={{ padding: '1.15rem' }}>
          <div style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.75rem' }}>
            Copies
          </div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <button
              type="button"
              onClick={() => updateActiveConfig({ copies: Math.max(1, activeConfig.copies - 1) })}
              disabled={activeConfig.copies <= 1}
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '10px',
                background: 'var(--surface-subtle)',
                border: '1px solid var(--border)',
                fontWeight: 800,
                fontSize: '1.2rem',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--text-primary)'
              }}
            >
              -
            </button>
            <span style={{ fontSize: '1.35rem', fontWeight: 800, color: 'var(--text-primary)' }}>
              {activeConfig.copies}
            </span>
            <button
              type="button"
              onClick={() => updateActiveConfig({ copies: activeConfig.copies + 1 })}
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '10px',
                background: 'var(--primary-surface)',
                border: '1px solid rgba(79, 70, 229, 0.25)',
                fontWeight: 800,
                fontSize: '1.2rem',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--primary)'
              }}
            >
              +
            </button>
          </div>
        </div>

        {/* Print Quality Dropdown */}
        <div className="card-white" style={{ padding: '1.15rem' }}>
          <div style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.75rem' }}>
            Print Quality
          </div>
          <select
            value={activeConfig.printQuality}
            onChange={(e) => updateActiveConfig({ printQuality: e.target.value })}
            style={{
              width: '100%',
              padding: '0.65rem 0.75rem',
              borderRadius: '10px',
              border: '1px solid var(--border)',
              background: 'var(--surface-subtle)',
              fontSize: '0.85rem',
              fontWeight: 700,
              color: 'var(--text-primary)'
            }}
          >
            <option value="Standard">Standard (300 DPI)</option>
            <option value="High (600 DPI)">High Quality (600 DPI)</option>
            <option value="Draft">Draft Fast</option>
          </select>
        </div>

      </div>

      {/* Paper Size & Orientation Card */}
      <div className="card-white" style={{ padding: '1.25rem', marginBottom: '1.15rem' }}>
        <div style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.85rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
          <Layers size={18} color="var(--primary)" />
          <span>Paper Size & Orientation</span>
        </div>

        <div style={{ marginBottom: '1rem' }}>
          <div style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.45rem' }}>
            Paper Size
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            {['A4', 'Letter', 'Legal'].map((size) => (
              <button
                key={size}
                type="button"
                onClick={() => updateActiveConfig({ paperSize: size })}
                style={{
                  flex: 1,
                  padding: '0.6rem',
                  borderRadius: '10px',
                  border: `1.5px solid ${activeConfig.paperSize === size ? 'var(--primary)' : 'var(--border)'}`,
                  background: activeConfig.paperSize === size ? 'var(--primary-surface)' : 'var(--surface-white)',
                  color: activeConfig.paperSize === size ? 'var(--primary)' : 'var(--text-secondary)',
                  fontWeight: 700,
                  fontSize: '0.85rem',
                  cursor: 'pointer',
                  transition: 'all 0.15s ease'
                }}
              >
                {size}
              </button>
            ))}
          </div>
        </div>

        <div>
          <div style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.45rem' }}>
            Orientation
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
            {['portrait', 'landscape'].map((orient) => (
              <button
                key={orient}
                type="button"
                onClick={() => updateActiveConfig({ orientation: orient })}
                style={{
                  padding: '0.6rem',
                  borderRadius: '10px',
                  border: `1.5px solid ${activeConfig.orientation === orient ? 'var(--primary)' : 'var(--border)'}`,
                  background: activeConfig.orientation === orient ? 'var(--primary-surface)' : 'var(--surface-white)',
                  color: activeConfig.orientation === orient ? 'var(--primary)' : 'var(--text-secondary)',
                  fontWeight: 700,
                  fontSize: '0.85rem',
                  cursor: 'pointer',
                  textTransform: 'capitalize',
                  transition: 'all 0.15s ease'
                }}
              >
                {orient}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Sides & Page Range Card */}
      <div className="card-white" style={{ padding: '1.25rem', marginBottom: '1.15rem' }}>
        <div style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.85rem', display: 'flex', alignItems: 'center', gap: '6px' }}>
          <FileSpreadsheet size={18} color="var(--primary)" />
          <span>Sides & Page Selection</span>
        </div>

        <div style={{ marginBottom: '1rem' }}>
          <div style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.45rem' }}>
            Print Sides
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
            <button
              type="button"
              onClick={() => updateActiveConfig({ sides: 'one-sided' })}
              style={{
                padding: '0.65rem',
                borderRadius: '10px',
                border: `1.5px solid ${activeConfig.sides === 'one-sided' ? 'var(--primary)' : 'var(--border)'}`,
                background: activeConfig.sides === 'one-sided' ? 'var(--primary-surface)' : 'var(--surface-white)',
                color: activeConfig.sides === 'one-sided' ? 'var(--primary)' : 'var(--text-secondary)',
                fontWeight: 700,
                fontSize: '0.85rem',
                cursor: 'pointer'
              }}
            >
              Single-sided
            </button>
            <button
              type="button"
              onClick={() => updateActiveConfig({ sides: 'two-sided-long-edge' })}
              style={{
                padding: '0.65rem',
                borderRadius: '10px',
                border: `1.5px solid ${activeConfig.sides !== 'one-sided' ? 'var(--primary)' : 'var(--border)'}`,
                background: activeConfig.sides !== 'one-sided' ? 'var(--primary-surface)' : 'var(--surface-white)',
                color: activeConfig.sides !== 'one-sided' ? 'var(--primary)' : 'var(--text-secondary)',
                fontWeight: 700,
                fontSize: '0.85rem',
                cursor: 'pointer'
              }}
            >
              Double-sided (Duplex)
            </button>
          </div>
        </div>

        <div>
          <div style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '0.45rem' }}>
            Page Range
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '6px', marginBottom: '0.75rem' }}>
            {[
              { id: 'all', label: 'All Pages' },
              { id: 'odd', label: 'Odd Pages' },
              { id: 'even', label: 'Even Pages' },
              { id: 'custom', label: 'Custom' }
            ].map((opt) => (
              <button
                key={opt.id}
                type="button"
                onClick={() => updateActiveConfig({ rangeOption: opt.id })}
                style={{
                  padding: '0.55rem',
                  borderRadius: '10px',
                  border: `1.5px solid ${activeConfig.rangeOption === opt.id ? 'var(--primary)' : 'var(--border)'}`,
                  background: activeConfig.rangeOption === opt.id ? 'var(--primary-surface)' : 'var(--surface-white)',
                  color: activeConfig.rangeOption === opt.id ? 'var(--primary)' : 'var(--text-secondary)',
                  fontWeight: 700,
                  fontSize: '0.8rem',
                  cursor: 'pointer'
                }}
              >
                {opt.label}
              </button>
            ))}
          </div>

          {activeConfig.rangeOption === 'custom' && (
            <div>
              <input
                type="text"
                placeholder="e.g. 1-3, 5, 8-10"
                value={activeConfig.customRange}
                onChange={(e) => updateActiveConfig({ customRange: e.target.value })}
                style={{
                  width: '100%',
                  padding: '0.65rem 0.85rem',
                  borderRadius: '10px',
                  border: '1.5px solid var(--primary)',
                  fontSize: '0.85rem',
                  background: 'var(--surface-white)'
                }}
              />
              <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                Total pages in file: {totalDocPages}. Example range format: 1-4, 7
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Estimated Cost Breakdown Card */}
      <div style={{
        background: 'var(--primary-surface)',
        border: '1.5px solid rgba(79, 70, 229, 0.25)',
        borderRadius: '20px',
        padding: '1.15rem 1.25rem',
        marginBottom: '1.5rem',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '0.85rem'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div style={{
            width: '40px',
            height: '40px',
            borderRadius: '10px',
            background: 'var(--primary-gradient)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'white'
          }}>
            <Calculator size={20} />
          </div>
          <div>
            <div style={{ fontSize: '0.85rem', fontWeight: 800, color: 'var(--primary-dark)' }}>
              Estimated Price Breakdown
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
              {docList.length > 1
                ? `${docList.length} documents • ${totalPagesToPrint} total pages`
                : `${activePages} page(s) × ${activeConfig.copies} copies @ ₹${activeRate}/pg`}
            </div>
          </div>
        </div>

        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>Total Estimated</div>
          <div style={{ fontSize: '1.45rem', fontWeight: 900, color: 'var(--primary)', letterSpacing: '-0.5px' }}>
            ₹{totalCalculatedCost.toFixed(2)}
          </div>
        </div>
      </div>

      {/* Bottom Sticky Action Bar */}
      <div style={{
        background: 'var(--surface-white)',
        borderTop: '1px solid var(--border)',
        padding: '1rem 1.25rem',
        borderRadius: '20px',
        boxShadow: 'var(--card-shadow)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '0.85rem'
      }}>
        <div>
          <div style={{ fontSize: '0.92rem', fontWeight: 800, color: 'var(--text-primary)' }}>
            Total: ₹{totalCalculatedCost.toFixed(2)}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)' }}>
            Includes all print options & taxes
          </div>
        </div>

        <button
          onClick={handleProceedToPayment}
          disabled={submitting}
          className="btn-primary"
          style={{
            padding: '0.85rem 1.85rem',
            borderRadius: '16px',
            fontSize: '0.95rem'
          }}
        >
          {submitting ? (
            <>
              <Loader2 size={18} className="animate-spin" />
              <span>Preparing Order...</span>
            </>
          ) : (
            <>
              <span>Proceed to Payment (₹{totalCalculatedCost.toFixed(2)})</span>
              <ArrowRight size={18} />
            </>
          )}
        </button>
      </div>

    </div>
  );
}
