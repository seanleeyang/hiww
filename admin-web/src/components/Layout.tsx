import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

const NAV_ITEMS = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/disputes', label: 'Disputes' },
  { to: '/id-checks', label: 'ID checks' },
  { to: '/flagged', label: 'Flagged content' },
  { to: '/orders', label: 'Orders' },
  { to: '/trips', label: 'Trips' },
  { to: '/wants', label: 'Wants' },
  { to: '/offers', label: 'Offers' },
  { to: '/reviews', label: 'Reviews' },
  { to: '/users', label: 'Users' },
  { to: '/money', label: 'Money' },
  { to: '/audit', label: 'Audit log' },
];

export function Layout() {
  const { me, logout } = useAuth();

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="sidebar-brand">Hiww Admin</div>
        <nav className="sidebar-nav">
          {NAV_ITEMS.map((item) => (
            <NavLink key={item.to} to={item.to} className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}>
              {item.label}
            </NavLink>
          ))}
          <div className="sidebar-divider" />
          <NavLink to="/dev-tools" className={({ isActive }) => (isActive ? 'nav-item nav-item-muted active' : 'nav-item nav-item-muted')}>
            Developer tools
          </NavLink>
        </nav>
        <div className="sidebar-footer">
          <div className="sidebar-me">{me?.full_name}</div>
          <button type="button" className="btn btn-ghost btn-small" onClick={logout}>
            Sign out
          </button>
        </div>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
