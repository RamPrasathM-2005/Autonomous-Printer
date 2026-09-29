// src/hooks/useSnackbar.js
// Global snackbar state — call show() from any screen, SnackbarHost renders it.
import { create } from 'zustand';

const useSnackbarStore = create((set) => ({
  visible:  false,
  message:  '',
  action:   null, // { label: string, onPress: () => void }

  show: (message, action = null) => set({ visible: true, message, action }),
  hide: () => set({ visible: false, message: '', action: null }),
}));

/**
 * Hook to show/hide the global Snackbar.
 * @returns {{ show, hide, visible, message, action }}
 */
export function useSnackbar() {
  return useSnackbarStore();
}
