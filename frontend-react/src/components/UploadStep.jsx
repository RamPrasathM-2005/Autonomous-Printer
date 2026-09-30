import React, { useState, useRef } from 'react';
import { UploadCloud, FileText, Trash2, ArrowRight, Loader2, AlertCircle, Printer, FolderOpen, CheckCircle2 } from 'lucide-react';
import { api } from '../api';

export default function UploadStep({ onNext }) {
  const [dragActive, setDragActive] = useState(false);
  const [selectedFiles, setSelectedFiles] = useState([]);
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
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      addFiles(Array.from(e.dataTransfer.files));
    }
  };

  const handleChange = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      addFiles(Array.from(e.target.files));
    }
  };

  const addFiles = (newFiles) => {
    setError(null);
    const validExtensions = ['pdf', 'png', 'jpg', 'jpeg'];
    const validList = [];

    for (const file of newFiles) {
      const ext = file.name.split('.').pop().toLowerCase();
      if (!validExtensions.includes(ext)) {
        setError('Unsupported format. Only PDF, PNG, and JPG files are supported.');
        continue;
      }
      // Avoid duplicate file names of same size
      if (!selectedFiles.some(f => f.name === file.name && f.size === file.size)) {
        validList.push(file);
      }
    }

    if (validList.length > 0) {
      setSelectedFiles(prev => [...prev, ...validList]);
    }
  };

  const removeFile = (index) => {
    setSelectedFiles(prev => prev.filter((_, i) => i !== index));
  };

  const handleUploadAndProceed = async () => {
    if (selectedFiles.length === 0) return;
    setUploading(true);
    setError(null);

    try {
      const uploadedDocs = [];
      for (const file of selectedFiles) {
        const doc = await api.uploadDocument(file);
        uploadedDocs.push(doc);
      }
      onNext(uploadedDocs);
    } catch (err) {
      setError(err.message || 'Failed to upload documents. Please check backend connection and retry.');
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

  const totalBytes = selectedFiles.reduce((acc, f) => acc + f.size, 0);

  return (
    <div style={{ maxWidth: '720px', margin: '0 auto' }}>

      {/* Section Title & Subtitle */}
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: '1.15rem' }}>
        <div>
          <h2 style={{ fontSize: '1.45rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px', margin: 0 }}>
            Select Documents
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', margin: '0.2rem 0 0 0' }}>
            Upload your PDF or image files to start printing.
          </p>
        </div>
        {selectedFiles.length > 0 && (
          <span style={{
            background: 'var(--primary-surface)',
            color: 'var(--primary)',
            padding: '4px 12px',
            borderRadius: '20px',
            fontSize: '0.78rem',
            fontWeight: 700,
            border: '1px solid rgba(79, 70, 229, 0.2)'
          }}>
            {selectedFiles.length} file(s) selected
          </span>
        )}
      </div>

      {/* Error Banner */}
      {error && (
        <div style={{
          background: 'var(--danger-surface)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: 'var(--danger)',
          padding: '0.75rem 1rem',
          borderRadius: '14px',
          display: 'flex',
          alignItems: 'center',
          gap: '0.65rem',
          fontSize: '0.85rem',
          marginBottom: '1rem'
        }}>
          <AlertCircle size={18} />
          <span style={{ flex: 1 }}>{error}</span>
          <button
            onClick={() => setError(null)}
            style={{ background: 'transparent', border: 'none', color: 'inherit', cursor: 'pointer', fontWeight: 700 }}
          >
            &times;
          </button>
        </div>
      )}

      {/* Dropzone Card - Exactly matches Flutter _buildDropzoneCard */}
      <div
        className={`dropzone ${dragActive ? 'drag-active' : ''}`}
        onDragEnter={handleDrag}
        onDragOver={handleDrag}
        onDragLeave={handleDrag}
        onDrop={handleDrop}
        onClick={() => inputRef.current?.click()}
        style={{
          background: 'var(--surface-white)',
          border: '2px solid rgba(79, 70, 229, 0.22)',
          borderRadius: '24px',
          padding: '2.5rem 1.5rem',
          textAlign: 'center',
          cursor: 'pointer',
          boxShadow: 'var(--card-shadow)',
          marginBottom: '1.5rem',
          transition: 'all 0.2s ease'
        }}
      >
        <input
          ref={inputRef}
          type="file"
          multiple
          accept=".pdf,.png,.jpg,.jpeg"
          onChange={handleChange}
          style={{ display: 'none' }}
        />

        {/* Circular Double Ring Container with Gradient Icon */}
        <div style={{
          width: '84px',
          height: '84px',
          borderRadius: '50%',
          background: 'var(--primary-surface)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          margin: '0 auto 1.25rem',
          border: '2px solid rgba(79, 70, 229, 0.15)'
        }}>
          <div style={{
            width: '62px',
            height: '62px',
            borderRadius: '50%',
            background: 'var(--primary-gradient)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'white',
            boxShadow: '0 4px 14px rgba(79, 70, 229, 0.35)'
          }}>
            <UploadCloud size={30} />
          </div>
        </div>

        <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.35rem', letterSpacing: '-0.2px' }}>
          Choose your file to upload
        </h3>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', marginBottom: '1.25rem' }}>
          Drag and drop or browse PDF, PNG, or JPG files
        </p>

        {/* Rose Accent Browse Button (Reference Image 1: #EC4899) */}
        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); inputRef.current?.click(); }}
          style={{
            background: 'var(--accent)',
            color: 'white',
            border: 'none',
            borderRadius: '14px',
            padding: '0.75rem 2rem',
            fontSize: '0.92rem',
            fontWeight: 700,
            cursor: 'pointer',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.5rem',
            boxShadow: '0 4px 14px rgba(236, 72, 153, 0.35)',
            transition: 'all 0.15s ease'
          }}
        >
          <FolderOpen size={18} />
          <span>Browse Files</span>
        </button>
      </div>

      {/* Selected Files Progress Listing */}
      {selectedFiles.length > 0 && (
        <div style={{ marginBottom: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
            <span style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-primary)' }}>
              File Uploading Progress
            </span>
            <span style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--text-secondary)' }}>
              Total: {formatSize(totalBytes)}
            </span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.65rem' }}>
            {selectedFiles.map((file, idx) => {
              const ext = file.name.split('.').pop().toUpperCase();
              return (
                <div
                  key={idx}
                  className="card-white"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.85rem',
                    padding: '0.85rem 1rem',
                    borderRadius: '16px'
                  }}
                >
                  {/* File Badge Icon */}
                  <div style={{
                    width: '42px',
                    height: '42px',
                    borderRadius: '12px',
                    background: ext === 'PDF' ? 'rgba(239, 68, 68, 0.12)' : 'rgba(79, 70, 229, 0.12)',
                    color: ext === 'PDF' ? '#ef4444' : 'var(--primary)',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: 800,
                    fontSize: '0.65rem',
                    flexShrink: 0
                  }}>
                    <FileText size={18} />
                    <span>{ext}</span>
                  </div>

                  {/* File Details & Progress */}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <span style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {file.name}
                      </span>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginLeft: '8px' }}>
                        {formatSize(file.size)}
                      </span>
                    </div>
                    {/* Simulated 100% Progress Bar */}
                    <div style={{ height: '4px', background: '#e2e8f0', borderRadius: '9999px', marginTop: '6px', overflow: 'hidden' }}>
                      <div style={{ width: '100%', height: '100%', background: 'var(--success)' }} />
                    </div>
                  </div>

                  {/* Delete Button */}
                  <button
                    type="button"
                    onClick={() => removeFile(idx)}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      color: 'var(--text-muted)',
                      cursor: 'pointer',
                      padding: '6px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      borderRadius: '8px',
                      transition: 'all 0.15s ease'
                    }}
                    title="Remove file"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Bottom Action Bar - Matches Flutter UploadScreen bottom bar */}
      <div style={{
        background: 'var(--surface-white)',
        borderTop: '1px solid var(--border)',
        padding: '1rem 1.25rem',
        borderRadius: '20px',
        boxShadow: 'var(--card-shadow)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginTop: '1rem',
        flexWrap: 'wrap',
        gap: '0.85rem'
      }}>
        <div>
          <div style={{ fontSize: '0.92rem', fontWeight: 800, color: 'var(--text-primary)' }}>
            {selectedFiles.length === 0 ? 'No documents selected' : `${selectedFiles.length} file(s) ready`}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)' }}>
            {selectedFiles.length === 0 ? 'Select PDF or images above' : `Total size: ${formatSize(totalBytes)}`}
          </div>
        </div>

        <button
          onClick={handleUploadAndProceed}
          disabled={selectedFiles.length === 0 || uploading}
          className="btn-primary"
          style={{
            padding: '0.85rem 1.85rem',
            borderRadius: '16px',
            fontSize: '0.95rem'
          }}
        >
          {uploading ? (
            <>
              <Loader2 size={18} className="animate-spin" />
              <span>Uploading Files...</span>
            </>
          ) : (
            <>
              <span>Continue to Options</span>
              <ArrowRight size={18} />
            </>
          )}
        </button>
      </div>

    </div>
  );
}
