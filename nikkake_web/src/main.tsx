import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { App } from './App';
import './theme/tokens.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // サーバが集計済みの値を返すので、画面ごとに1リクエストで足りる
      staleTime: 0,
      retry: false,
      refetchOnWindowFocus: true,
    },
  },
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </StrictMode>,
);
