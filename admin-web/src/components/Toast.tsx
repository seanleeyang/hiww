import { createContext, use, useCallback, useRef, useState, type ReactNode } from 'react';

interface ToastItem {
  id: number;
  message: string;
  tone: 'success' | 'error';
}

type ShowToast = (message: string, tone?: 'success' | 'error') => void;

const ToastContext = createContext<ShowToast | null>(null);

/** A lightweight, app-wide "it worked" / "it failed" signal — every
 * money-moving or state-changing action should call this on success so the
 * result of a tap is never just "the modal closed and something on the page
 * quietly changed." */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const nextId = useRef(0);

  const show = useCallback<ShowToast>((message, tone = 'success') => {
    const id = nextId.current++;
    setItems((prev) => [...prev, { id, message, tone }]);
    setTimeout(() => {
      setItems((prev) => prev.filter((t) => t.id !== id));
    }, 4000);
  }, []);

  return (
    <ToastContext value={show}>
      {children}
      <div className="toast-stack" role="status" aria-live="polite">
        {items.map((t) => (
          <div key={t.id} className={`toast toast-${t.tone}`}>
            {t.message}
          </div>
        ))}
      </div>
    </ToastContext>
  );
}

export function useToast(): ShowToast {
  const ctx = use(ToastContext);
  if (!ctx) throw new Error('useToast must be used inside ToastProvider');
  return ctx;
}
