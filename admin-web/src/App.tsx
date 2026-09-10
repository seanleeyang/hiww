import { Suspense, lazy, type ComponentType, type ReactElement } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import { LoginPage } from './auth/LoginPage';
import { Layout } from './components/Layout';
import { DashboardPage } from './pages/DashboardPage';

// Route-level code splitting: a visitor only ever looks at one page at a
// time, so there's no reason to ship all 13 pages' JS on first load — each
// becomes its own chunk, fetched only when its route is actually visited.
// DashboardPage is the one exception, imported eagerly above: "/" always
// redirects there, so every session needs it immediately — lazy-loading it
// too would add a network round trip (fetch bundle → evaluate → redirect →
// *then* fetch the dashboard chunk) instead of loading it in parallel with
// the main bundle like it does today.
const DisputesPage = lazy(() => import('./pages/DisputesPage').then((m) => ({ default: m.DisputesPage })));
const IdChecksPage = lazy(() => import('./pages/IdChecksPage').then((m) => ({ default: m.IdChecksPage })));
const FlaggedContentPage = lazy(() =>
  import('./pages/FlaggedContentPage').then((m) => ({ default: m.FlaggedContentPage }))
);
const OrdersListPage = lazy(() => import('./pages/OrdersListPage').then((m) => ({ default: m.OrdersListPage })));
const OrderDetailPage = lazy(() => import('./pages/OrderDetailPage').then((m) => ({ default: m.OrderDetailPage })));
const TripsPage = lazy(() => import('./pages/TripsPage').then((m) => ({ default: m.TripsPage })));
const WantsPage = lazy(() => import('./pages/WantsPage').then((m) => ({ default: m.WantsPage })));
const OffersPage = lazy(() => import('./pages/OffersPage').then((m) => ({ default: m.OffersPage })));
const ReviewsPage = lazy(() => import('./pages/ReviewsPage').then((m) => ({ default: m.ReviewsPage })));
const UsersPage = lazy(() => import('./pages/UsersPage').then((m) => ({ default: m.UsersPage })));
const MoneyPage = lazy(() => import('./pages/MoneyPage').then((m) => ({ default: m.MoneyPage })));
const AuditPage = lazy(() => import('./pages/AuditPage').then((m) => ({ default: m.AuditPage })));
const DevToolsPage = lazy(() => import('./pages/DevToolsPage').then((m) => ({ default: m.DevToolsPage })));

function page(Component: ComponentType): ReactElement {
  return (
    <Suspense fallback={<p className="loading-state">Loading…</p>}>
      <Component />
    </Suspense>
  );
}

export function App() {
  const { status } = useAuth();

  if (status === 'checking') {
    return <div className="auth-screen">Loading…</div>;
  }

  if (status === 'signed-out' || status === 'forbidden') {
    return <LoginPage />;
  }

  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/disputes" element={page(DisputesPage)} />
        <Route path="/id-checks" element={page(IdChecksPage)} />
        <Route path="/flagged" element={page(FlaggedContentPage)} />
        <Route path="/orders" element={page(OrdersListPage)} />
        <Route path="/orders/:id" element={page(OrderDetailPage)} />
        <Route path="/trips" element={page(TripsPage)} />
        <Route path="/wants" element={page(WantsPage)} />
        <Route path="/offers" element={page(OffersPage)} />
        <Route path="/reviews" element={page(ReviewsPage)} />
        <Route path="/users" element={page(UsersPage)} />
        <Route path="/money" element={page(MoneyPage)} />
        <Route path="/audit" element={page(AuditPage)} />
        <Route path="/dev-tools" element={page(DevToolsPage)} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Route>
    </Routes>
  );
}
