import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  Database,
  Gauge,
  LockKeyhole,
  RefreshCw,
  Server,
  ShieldCheck,
  UserPlus,
  Users,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "/api";

const fallbackSummary = {
  timestamp: new Date().toISOString(),
  services: [
    { name: "api", status: "unknown", target: "http://api:8000" },
    { name: "postgres", status: "unknown", target: "postgres:5432" },
    { name: "redis", status: "unknown", target: "redis:6379" },
  ],
  kpis: {
    registered_users: 0,
    healthy_services: 0,
    policy_mode: "enforce",
    environment: "development",
  },
};

function classNames(...values) {
  return values.filter(Boolean).join(" ");
}

async function fetchJson(path, options) {
  const response = await fetch(`${API_BASE}${path}`, options);
  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed with ${response.status}`);
  }
  return response.json();
}

function App() {
  const [summary, setSummary] = useState(fallbackSummary);
  const [users, setUsers] = useState([]);
  const [status, setStatus] = useState("loading");
  const [error, setError] = useState("");
  const [form, setForm] = useState({ name: "", email: "" });
  const [saving, setSaving] = useState(false);

  const healthyServices = useMemo(
    () => summary.services.filter((service) => service.status === "healthy").length,
    [summary.services],
  );

  async function refresh() {
    setStatus("loading");
    setError("");
    try {
      const [nextSummary, nextUsers] = await Promise.all([
        fetchJson("/observability/summary"),
        fetchJson("/users"),
      ]);
      setSummary(nextSummary);
      setUsers(nextUsers);
      setStatus("ready");
    } catch (nextError) {
      setError(nextError.message);
      setStatus("degraded");
    }
  }

  async function createUser(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      await fetchJson("/users", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      setForm({ name: "", email: "" });
      await refresh();
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setSaving(false);
    }
  }

  useEffect(() => {
    refresh();
    const timer = window.setInterval(refresh, 30000);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <main className="app-shell">
      <aside className="sidebar" aria-label="Primary">
        <div className="brand">
          <ShieldCheck aria-hidden="true" />
          <span>SecureOps</span>
        </div>
        <nav>
          <a className="active" href="#overview">
            <Gauge aria-hidden="true" />
            Overview
          </a>
          <a href="#services">
            <Server aria-hidden="true" />
            Services
          </a>
          <a href="#users">
            <Users aria-hidden="true" />
            Users
          </a>
          <a href="#security">
            <LockKeyhole aria-hidden="true" />
            Security
          </a>
        </nav>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">Kubernetes Observability</p>
            <h1>Platform Control Plane</h1>
          </div>
          <button className="icon-button" onClick={refresh} title="Refresh" type="button">
            <RefreshCw aria-hidden="true" className={status === "loading" ? "spin" : ""} />
            <span>Refresh</span>
          </button>
        </header>

        {error ? (
          <div className="alert" role="alert">
            <AlertTriangle aria-hidden="true" />
            <span>{error}</span>
          </div>
        ) : null}

        <section className="kpi-grid" id="overview">
          <MetricCard
            icon={<Activity aria-hidden="true" />}
            label="Service health"
            value={`${healthyServices}/${summary.services.length}`}
            trend={status}
          />
          <MetricCard
            icon={<Users aria-hidden="true" />}
            label="Registered users"
            value={summary.kpis.registered_users}
            trend="tracked"
          />
          <MetricCard
            icon={<ShieldCheck aria-hidden="true" />}
            label="Policy mode"
            value={summary.kpis.policy_mode}
            trend="Kyverno"
          />
          <MetricCard
            icon={<Database aria-hidden="true" />}
            label="Environment"
            value={summary.kpis.environment}
            trend="active"
          />
        </section>

        <section className="content-grid">
          <div className="panel" id="services">
            <div className="panel-title">
              <h2>Service Targets</h2>
              <span>{new Date(summary.timestamp).toLocaleTimeString()}</span>
            </div>
            <div className="service-list">
              {summary.services.map((service) => (
                <article className="service-row" key={service.name}>
                  <div className="service-name">
                    <Server aria-hidden="true" />
                    <div>
                      <strong>{service.name}</strong>
                      <small>{service.target}</small>
                    </div>
                  </div>
                  <span className={classNames("status-pill", service.status)}>
                    {service.status}
                  </span>
                </article>
              ))}
            </div>
          </div>

          <div className="panel" id="security">
            <div className="panel-title">
              <h2>Security Posture</h2>
              <span>baseline</span>
            </div>
            <div className="posture-list">
              <PostureItem label="Non-root workloads" />
              <PostureItem label="Read-only root filesystems" />
              <PostureItem label="Resource requests and limits" />
              <PostureItem label="Network policy boundaries" />
            </div>
          </div>

          <div className="panel wide" id="users">
            <div className="panel-title">
              <h2>User Registry</h2>
              <span>{users.length} records</span>
            </div>
            <form className="user-form" onSubmit={createUser}>
              <input
                aria-label="Name"
                onChange={(event) => setForm({ ...form, name: event.target.value })}
                placeholder="Name"
                required
                value={form.name}
              />
              <input
                aria-label="Email"
                onChange={(event) => setForm({ ...form, email: event.target.value })}
                placeholder="Email"
                required
                type="email"
                value={form.email}
              />
              <button className="icon-button primary" disabled={saving} type="submit">
                <UserPlus aria-hidden="true" />
                <span>{saving ? "Saving" : "Add"}</span>
              </button>
            </form>
            <div className="user-table">
              <div className="user-table-header">
                <span>Name</span>
                <span>Email</span>
                <span>Created</span>
              </div>
              {users.map((user) => (
                <div className="user-table-row" key={user.id}>
                  <span>{user.name}</span>
                  <span>{user.email}</span>
                  <span>{new Date(user.created_at).toLocaleString()}</span>
                </div>
              ))}
              {!users.length ? <div className="empty-row">No users yet</div> : null}
            </div>
          </div>
        </section>
      </section>
    </main>
  );
}

function MetricCard({ icon, label, value, trend }) {
  return (
    <article className="metric-card">
      <div className="metric-icon">{icon}</div>
      <div>
        <span>{label}</span>
        <strong>{value}</strong>
        <small>{trend}</small>
      </div>
    </article>
  );
}

function PostureItem({ label }) {
  return (
    <div className="posture-item">
      <CheckCircle2 aria-hidden="true" />
      <span>{label}</span>
    </div>
  );
}

export default App;

