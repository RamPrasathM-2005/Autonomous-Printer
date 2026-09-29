// src/store/documentStore.js
import { create } from 'zustand';

const initialState = {
  documents: [], // Array of UploadedDocument objects
};

const useDocumentStore = create((set, get) => ({
  ...initialState,

  // Add a newly uploaded document
  addDocument: (doc) =>
    set((state) => ({ documents: [...state.documents, doc] })),

  // Update a document's fields (e.g., status, thumbnailUrl)
  updateDocument: (documentId, updates) =>
    set((state) => ({
      documents: state.documents.map((d) =>
        d.documentId === documentId ? { ...d, ...updates } : d
      ),
    })),

  // Remove a document by ID
  removeDocument: (documentId) =>
    set((state) => ({
      documents: state.documents.filter((d) => d.documentId !== documentId),
    })),

  // Selectors (called on the store instance)
  getDocumentById: (documentId) =>
    get().documents.find((d) => d.documentId === documentId) || null,

  // Reset entire store (called on session end)
  reset: () => set(initialState),
}));

export default useDocumentStore;
