import React, { useState, useRef } from 'react';
import { UploadCloud, FileText, Trash2, ArrowRight, Loader2, AlertCircle } from 'lucide-react';
import { api } from '../api';

export default function UploadStep({ onNext }) {
  const [dragActive, setDragActive] = useState(false);
  const [selectedFile, setSelectedFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState(null);
  const inputRef = useRef(null);

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      validateAndSetFile(e.dataTransfer.files[0]);
    }
  };

  const handleChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      validateAndSetFile(e.target.files[0]);
    }
  };

  const validateAndSetFile = (file) => {
    setError(null);
    const validExtensions = ['pdf', 'png', 'jpg', 'jpeg'];
    const ext = file.name.split('.').pop().toLowerCase();
    if (!validExtensions.includes(ext)) {
      setError('Please upload a PDF or Image file (.pdf, .png, .jpg, .jpeg)');
      return;
    }
    setSelectedFile(file);
  };

  const handleUploadAndProceed = async () => {
    if (!selectedFile) return;
    setUploading(true);
    setError(null);

    try {
      const doc = await api.uploadDocument(selectedFile);
      onNext(doc);
    } catch (err) {
      setError(err.message || 'Failed to upload document. Please retry.');
    } finally {
      setUploading(false);
    }
  };

  const formatSize = (bytes) => {
    if (!bytes) return '0 B';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  return (
    <div>
      {/* Section Title & Subtitle - Matches Flutter UploadScreen */}
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: '1.25rem' }}>
        <div>
          <h2 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px' }}>
            Select Documents
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', marginTop: '0.2rem' }}>
            Upload your PDF or image files to start printing.
          </p>
        </div>
        {selectedFile && (
          <span style={{
            background: 'var(--primary-surface)',
            color: 'var(--primary)',
            padding: '4px 12px',
            borderRadius: '20px',
            fontSize: '0.78rem',
            fontWeight: 700,
            border: '1px solid rgba(79, 70, 229, 0.2)'
          }}>
            1 file selected
          </span>
        )}
      </div>

      {/* Dropzone */}
      <div
        className={`dropzone ${dragActive ? 'drag-active' : ''}`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
        onClick={() => inputRef.current?.click()}
      >
        <input
          ref={inputRef}
          type="file"
          accept=".pdf,.png,.jpg,.jpeg"
          style={{ display: 'none' }}
          onChange={handleChange}
        />
        <div className="dropzone-icon">
          <UploadCloud size={32} />
        </div>
        <div className="dropzone-title">Drop your document here</div>
        <div className="dropzone-subtitle">Supports PDF, PNG, JPG up to 50MB</div>
        <button
          type="button"
          className="browse-btn"
          onClick={(e) => {
            e.stopPropagation();
            inputRef.current?.click();
          }}
        >
          Select File from Device
        </button>
      </div>

      {/* Error alert */}
      {error && (
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '0.75rem',
          background: 'var(--danger-surface)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: 'var(--danger)',
          padding: '0.85rem 1.25rem',
          borderRadius: 'var(--radius-md)',
          margin: '1.25rem 0',
          fontSize: '0.88rem',
          fontWeight: 500
        }}>
          <AlertCircle size={18} />
          <span>{error}</span>
        </div>
      )}

      {/* Selected File Card */}
      {selectedFile && (
        <div style={{ marginTop: '1.5rem' }}>
          <div className="doc-card">
            <div className="doc-info">
              <div className="doc-icon-box">
                <FileText size={22} />
              </div>
              <div>
                <div className="doc-name">{selectedFile.name}</div>
                <div className="doc-meta">
                  <span style={{
                    background: 'var(--primary-surface)',
                    color: 'var(--primary)',
                    padding: '1px 6px',
                    borderRadius: '6px',
                    fontWeight: 700,
                    fontSize: '0.72rem'
                  }}>
                    {selectedFile.name.split('.').pop().toUpperCase()}
                  </span>
                  <span>{formatSize(selectedFile.size)}</span>
                  <span>•</span>
                  <span>Ready to print</span>
                </div>
              </div>
            </div>
            <button
              onClick={() => setSelectedFile(null)}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--text-muted)',
                cursor: 'pointer',
                padding: '0.5rem',
                borderRadius: '8px',
                transition: 'color 0.15s'
              }}
              onMouseEnter={(e) => e.target.style.color = 'var(--danger)'}
              onMouseLeave={(e) => e.target.style.color = 'var(--text-muted)'}
              title="Remove document"
            >
              <Trash2 size={18} />
            </button>
          </div>

          <div style={{ marginTop: '1.75rem' }}>
            <button
              className="btn-primary"
              onClick={handleUploadAndProceed}
              disabled={uploading}
            >
              {uploading ? (
                <>
                  <Loader2 size={18} className="animate-spin" style={{ animation: 'spin 1s linear infinite' }} />
                  <span>Uploading & Analyzing Document...</span>
                </>
              ) : (
                <>
                  <span>Configure Print Options</span>
                  <ArrowRight size={18} />
                </>
              )}
            </button>
          </div>
        </div>
      )}

      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
