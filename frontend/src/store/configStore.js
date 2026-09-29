// src/store/configStore.js
// Stores per-document print configurations: { [documentId]: PrintConfiguration }
import { create } from 'zustand';

const initialState = {
  configurations: {}, // documentId -> PrintConfiguration
};

const useConfigStore = create((set, get) => ({
  ...initialState,

  // Save or overwrite configuration for a document
  saveConfiguration: (documentId, config) =>
    set((state) => ({
      configurations: { ...state.configurations, [documentId]: config },
    })),

  // Remove configuration for a document (e.g., on document delete)
  removeConfiguration: (documentId) =>
    set((state) => {
      const { [documentId]: _removed, ...rest } = state.configurations;
      return { configurations: rest };
    }),

  // Get configuration for a specific document
  getConfiguration: (documentId) => get().configurations[documentId] || null,

  // Check if all provided documentIds have a saved configuration
  allConfigured: (documentIds) =>
    documentIds.every((id) => id in get().configurations),

  reset: () => set(initialState),
}));

export default useConfigStore;
