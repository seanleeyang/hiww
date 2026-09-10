import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import { LoginPage } from './auth/LoginPage';
import { Layout } from './components/Layout';
import { DashboardPage } from './pages/DashboardPage';
import { DisputesPage } from './pages/DisputesPage';
import { IdChecksPage } from './pages/IdChecksPage';
import { FlaggedContentPage } from './pages/FlaggedContentPage';
import { OrdersListPage } from './pages/OrdersListPage';
import { OrderDetailPage } from './pages/OrderDetailPage';
import { TripsPage } from './pages/TripsPage';
import { WantsPage } from './pages/WantsPage';
import { OffersPage } from './pages/OffersPage';
import { ReviewsPage } from './pages/ReviewsPage';
import { UsersPage } from './pages/UsersPage';
import { MoneyPage } from './pages/MoneyPage';
import { AuditPage } from './pages/AuditPage';
import { DevToolsPage } from './pages/DevToolsPage';

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
        <Route path="/disputes" element={<DisputesPage />} />
        <Route path="/id-checks" element={<IdChecksPage />} />
        <Route path="/flagged" element={<FlaggedContentPage />} />
        <Route path="/orders" element={<OrdersListPage />} />
        <Route path="/orders/:id" element={<OrderDetailPage />} />
        <Route path="/trips" element={<TripsPage />} />
        <Route path="/wants" element={<WantsPage />} />
        <Route path="/offers" element={<OffersPage />} />
        <Route path="/reviews" element={<ReviewsPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/money" element={<MoneyPage />} />
        <Route path="/audit" element={<AuditPage />} />
        <Route path="/dev-tools" element={<DevToolsPage />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Route>
    </Routes>
  );
}
