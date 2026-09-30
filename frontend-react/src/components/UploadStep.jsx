import React, { useState, useRef } from 'react';
import { UploadCloud, FileText, Trash2, ArrowRight, Loader2, AlertCircle, FileCheck } from 'lucide-react';
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
    const ext = file.name.split('.').last || file.name.split('.').pop().toLowerCase();
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
      <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
        <h1 style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '0.6rem' }}>
          Upload Documents to Print
        </h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '1rem', maxWidth: '600px', margin: '0 auto' }}>
          Secure autonomous print pipeline. Upload your PDF or images and customize color, copies, and paper sizing.
        </p>
      </div>

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
          <UploadCloud size={34} />
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

      {error && (
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '0.75rem',
          background: 'rgba(239, 68, 68, 0.1)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: '#f87171',
          padding: '1rem 1.25rem',
          borderRadius: 'var(--radius-md)',
          margin: '1.5rem 0'
        }}>
          <AlertCircle size={20} />
          <span>{error}</span>
        </div>
      )}

      {selectedFile && (
        <div style={{ marginTop: '2rem' }}>
          <h3 style={{ fontSize: '1.1rem', marginBottom: '1rem', color: 'var(--text-muted)' }}>
            Selected Document
          </h3>
          <div className="doc-card">
            <div className="doc-info">
              <div className="doc-icon-box">
                <FileText size={24} />
              </div>
              <div>
                <div className="doc-name">{selectedFile.name}</div>
                <div className="doc-meta">
                  <span>{formatSize(selectedFile.size)}</span>
                  <span>•</span>
                  <span>Ready to process</span>
                </div>
              </div>
            </div>
            <button
              onClick={() => setSelectedFile(null)}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--text-dim)',
                cursor: 'pointer',
                padding: '0.5rem',
                borderRadius: 'var(--radius-sm)',
                transition: 'color 0.2s'
              }}
              onMouseEnter={(e) => e.target.style.color = '#ef4444'}
              onMouseLeave={(e) => e.target.style.color = 'var(--text-dim)'}
              title="Remove document"
            >
              <Trash2 size={20} />
            </button>
          </div>

          <div style={{ marginTop: '2rem' }}>
            <button
              className="btn-primary"
              onClick={handleUploadAndProceed}
              disabled={uploading}
            >
              {uploading ? (
                <>
                  <Loader2 size={20} className="animate-spin" style={{ animation: 'spin 1s linear infinite' }} />
                  <span>Processing & Uploading...</span>
                </>
              ) : (
                <>
                  <span>Configure Print Options</span>
                  <ArrowRight size={20} />
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
