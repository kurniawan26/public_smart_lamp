# Smart City Lamp

Phoenix LiveView MVP for simulating and monitoring municipal smart lamps through Leaflet, OpenStreetMap, PostgreSQL, Oban, and Phoenix PubSub.

## Architecture overview

The application is a non-umbrella Phoenix project with domain logic outside controllers and LiveViews:

- `SmartCityLamp.Accounts` owns admin credentials and authentication.
- `SmartCityLamp.Devices` owns the device registry and device audit events.
- `SmartCityLamp.Simulations` owns the public scenario allowlist, payload generation, cooldown, and orchestration.
- `SmartCityLamp.Simulations.LiveSensorBroadcaster` generates random environment/activity readings in memory and sends them directly through PubSub/WebSocket without database ingestion.
- `SmartCityLamp.Telemetry` validates and persists telemetry, invokes detection, updates devices, and broadcasts realtime events.
- `SmartCityLamp.Incidents` owns detection-driven incidents, lifecycle transitions, cooldown, and audit events.
- `SmartCityLamp.Monitoring` derives public/admin summaries and marker priority.
- `SmartCityLamp.Commands` persists and executes simulator-backed remote commands.
- `SmartCityLamp.Repairs` persists dispatches while the single-concurrency Oban `repairs` queue serializes technician travel and recovery work.
- `SmartCityLamp.Workers.HeartbeatWorker` uses Oban Cron to derive degraded/offline state.

## Access model

Public visitors do not have accounts. They can view public information and run predefined, backend-controlled simulation events. Monitoring details and all operational actions require an authenticated admin session.

### Public routes

| Route | Purpose |
| --- | --- |
| `/` | Public landing page |
| `/public-map` | Interactive map with a scenario drawer on each lamp |
| `/about` | MVP concept and access-boundary explanation |

The public map does not expose admin actions, resolution notes, audit metadata, tokens, commands, or sensitive configuration.

### Admin routes

| Route | Purpose |
| --- | --- |
| `/admin/login` | Admin sign-in |
| `/admin/dashboard` | Realtime monitoring map and incident operations |
| `/admin/devices` | Device registry |
| `/admin/devices/:id` | Device telemetry, charts, audit, maintenance, and commands |
| `/admin/incidents` | Incident management |
| `/admin/commands` | Command workspace |
| `/admin/settings` | Detection settings workspace |
| `/admin/simulator-controls` | Protected simulator controls workspace |

Anonymous admin requests redirect to `/admin/login`. Authenticated admins opening the login page are redirected to `/admin/dashboard`.

## Local setup

Requirements: Elixir 1.19+, Erlang/OTP, Docker, and Node/npm.

### Run the complete stack with Docker

The production-style container builds a Phoenix release, runs pending migrations on startup, and publishes the application on host port `4010` (Phoenix uses port `4000` only inside the container):

```bash
docker compose up --build
```

Open [http://localhost:4010](http://localhost:4010). PostgreSQL data is retained in the `smart_city_lamp_postgres_data` volume. The Compose credentials and `SECRET_KEY_BASE` are development-only defaults; replace them with secrets before any production deployment. The public emulator is enabled explicitly for this local demo stack.

Useful commands:

```bash
docker compose up --build -d
docker compose logs -f app
docker compose down
```

```bash
docker compose up -d postgres
mix setup
mix phx.server
```

Then open [http://localhost:4000](http://localhost:4000).

## Environment variables

Development PostgreSQL defaults to `localhost:5432` with user/password `postgres`.

Production requires:

```text
DATABASE_URL
SECRET_KEY_BASE
PHX_HOST
PORT
ENABLE_PUBLIC_EMULATOR
```

`ENABLE_PUBLIC_EMULATOR` defaults to `true` in development/test and `false` in production. When disabled, `/public-map` remains read-only, its drawer hides scenario controls, and `/api/simulator/events` returns `404 Not Found`.

## Database setup

```bash
docker compose up -d postgres
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

The idempotent seed creates 20 Jakarta devices: 15 normal, 2 warning, 1 offline, 1 suspected-vandalism, and 1 critical device.

## Admin login and demo credentials

Development seeds create this admin:

```text
email: admin@smartlamp.local
password: admin12345
```

These credentials are for local development/demo only. The default admin is not created when seeds run with `MIX_ENV=prod`. Production administrators must use unique, securely delivered credentials.

Passwords are stored using salted PBKDF2-HMAC-SHA256 hashes and verified with constant-time comparison. Login renews the session, and logout drops it.

## Interactive public map

Open [http://localhost:4000/public-map](http://localhost:4000/public-map) and click a lamp marker. Its detail drawer shows the current condition and allowlisted scenarios. Each scenario button runs immediately with one click and no confirmation dialog. The browser cannot submit raw sensor values, severity, incident state, arbitrary coordinates, or infrastructure commands.

Drawer actions are intentionally limited to physical/security events: hit lamp, open cabinet, disconnect power, tilt/move device, and device offline. Recovery is not exposed to public users or the public simulator API; only an authenticated admin can recover a device from its protected detail page.

Ambient temperature, humidity, rain/flood indicators, PM2.5/PM10, noise, crowd, and traffic values are produced every three seconds by a supervised GenServer. These readings are ephemeral: they are sent directly to public/admin LiveViews over PubSub/WebSocket and are not inserted into `telemetry_records`. A lamp with `power_failure`, lamp `offline`, or connectivity `offline` produces no live sensor broadcast until recovery.

Protection currently includes:

- explicit string-to-atom event mapping without `String.to_atom/1`;
- device validation;
- CSRF protection for LiveView forms/events;
- one event per device every two seconds;
- twenty events per session/IP per minute;
- backend-generated telemetry only.

The in-memory rate limiter is an abstraction suitable for a single-node MVP. A distributed production deployment should replace it with a shared limiter such as Redis-backed counters.

## Public simulator API

```bash
curl -X POST http://localhost:4000/api/simulator/events \
  -H 'content-type: application/json' \
  -d '{"device_code":"LAMP-JKT-001","event":"HIT_LAMP"}'
```

Successful and error responses use `{data, meta, errors}`. Extra sensor fields are ignored; only `device_code` and an allowlisted `event` are consumed.

The direct `/api/telemetry` endpoint remains the integration boundary for device clients. Before production use it must receive device-token authentication and production-grade rate limiting.

## Realtime synchronization

```text
Public Map Drawer
  → Simulations.run_scenario/3
  → Telemetry.ingest/1
  → telemetry/device transaction
  → 30-second detection window
  → device status + incident lifecycle
  → PubSub: telemetry, devices, device:<id>, incidents, dashboard
  → Admin DashboardLive / DeviceDetailLive / Public MapLive
  → marker, summary, telemetry stream, and incidents update without reload

LiveSensorBroadcaster (every 3 seconds)
  → skip offline / power-failure devices
  → generate random environment, noise, crowd, and traffic readings
  → PubSub: live_sensors + device:<id>
  → LiveView WebSocket
  → public drawer + admin ambient feed (no database insert)

Admin recovery
  → admin selects a lamp marker on the large dashboard map
  → persist dispatch and enqueue it in the single-technician Oban queue
  → the first job starts at Jakarta Technician Office
  → jobs waiting in the same batch continue from the previous lamp location
  → Leaflet Routing Machine requests an OSRM route
  → technician-svgrepo-com.svg animates along the route
  → the same read-only route and technician position appear on /public-map through PubSub
  → persisted timestamps let an interrupted worker resume the remaining travel/repair phase
  → repair delay completes
  → device recovery + audit + PubSub broadcast
  → when the batch queue is empty, the technician route returns to the office
```

Leaflet hooks receive a `devices_updated` LiveView event so map markers update while the Leaflet-owned DOM remains under `phx-update="ignore"`.

## Demo flow

1. Start PostgreSQL and Phoenix.
2. Open `http://localhost:4000/public-map`.
3. Open another browser at `http://localhost:4000/admin/login`.
4. Sign in with the development admin.
5. Open the admin dashboard.
6. Click the marker for `LAMP-JKT-001` to open its side drawer.
7. Run **Hit Lamp**.
8. Wait two seconds and run **Open Cabinet**.
9. Wait two seconds and run **Disconnect Power**.
10. Observe the marker and critical incident update without reload.
11. Acknowledge the incident as admin.
12. On the admin dashboard map, select the affected marker and click **Dispatch technician & recover** in the side drawer.
13. Watch the technician icon travel along the OSRM route on both the admin dashboard and public map.
14. Wait for the repair delay; the device becomes online only after repair completion.
15. Resolve the incident with a resolution note.

Print the same instructions with:

```bash
mix smart_city_lamp.demo dual_browser
```

The task intentionally prints URLs instead of attempting to open a platform-specific browser.

## Running tests

```bash
mix test
mix precommit
```

Tests cover schemas, detection engines, telemetry, incidents, cooldown, heartbeat, authentication, routing, authorization, the public simulator API, LiveView rendering, and dual-browser PubSub synchronization.

## Security limitations

- Public simulation controls inside the map drawer exist only for MVP demonstrations.
- The limiter is node-local and resets when the application restarts.
- Authentication has one `ADMIN` role; there is no public registration, password reset, social login, or email confirmation.
- Device management/settings workspaces are intentionally minimal in this MVP.
- The direct telemetry endpoint still needs device-token authentication before production use.
- Map tiles require browser access to OpenStreetMap tile infrastructure.
- Technician routing uses the public OSRM demo service and therefore requires network access; production should use a managed or self-hosted OSRM instance.

## Production recommendations

- Keep `ENABLE_PUBLIC_EMULATOR=false` unless a controlled demonstration requires it.
- Provision administrators outside public HTTP routes and enforce unique high-entropy passwords.
- Add TLS, secure cookie deployment settings, CSP review, and login rate limiting.
- Authenticate each physical device using a hashed device token or mutual TLS.
- Replace node-local simulation limiting with a distributed store.
- Add telemetry retention/archive jobs and tighter public-map aggregation.
- Place LiveDashboard and all operational APIs behind the same admin boundary.

## Future MQTT integration

MQTT should call the same `Telemetry.ingest/1` boundary after authenticating a device. This preserves validation, detection, incident creation, audit, and PubSub delivery without duplicating domain logic.
