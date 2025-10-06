# Control Plane Overview

The control plane orchestrates the platform services and exposes a single UI entry point for
operations teams. It is composed of open-source building blocks that cover lifecycle
management, log and metric collection, data lineage, and availability monitoring.

```
                        ┌─────────────────────────────┐
                        │         Traefik             │
                        │  reverse proxy + routing    │
                        └────────────┬────────────────┘
                                     │
    ┌─────────────────────────────────┴────────────────────────────────────────────┐
    │                                                                              │
┌────────┐  ┌────────────┐  ┌──────────┐  ┌───────────┐  ┌────────────┐  ┌────────┐
│ Dockge │  │   Grafana  │  │ Prometheus│ │   Loki    │  │  Marquez   │  │ Uptime │
│ manage │  │ dashboards │  │ metrics   │ │ log store │  │ lineage UI │  │  Kuma  │
│ stacks │  │ + alerts   │  │ gateway   │ │ + Promtail│  │ + API      │  │ status │
└────────┘  └────────────┘  └──────────┘  └───────────┘  └────────────┘  └────────┘
    │            │              │              │               │              │
    │            │              │              │               │              │
   docker      dashboards      scrape        collects        listens        monitors
 compose       + alerts        metrics       container       data jobs      http/icmp
 stacks                                       logs via                       probes
                                               Promtail
```

## Capabilities

| Capability                                         | Component                              | Notes                                                                                                                                                            |
|----------------------------------------------------|----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Start/stop the Docker based application stacks     | **Dockge**                             | Each service (data generators, Kafka, Spark, etc.) is modelled as a stack definition and can be started, stopped, or scaled from the Dockge UI.                  |
| Observe container and application logs             | **Loki + Promtail + Grafana Explore**  | Promtail tails every container log and ships it to Loki; Grafana provides the UI for querying logs.                                                              |
| Manage environment variables and compose overrides | **Dockge**                             | Stack configuration can be edited in-place from Dockge before (re)deploying; for reproducibility keep the updates under version control.                         |
| Monitor runtime health and metrics                 | **Prometheus + Grafana + Uptime Kuma** | Prometheus scrapes exporters (node exporter, cAdvisor, application exporters) and Grafana ships with starter dashboards; Uptime Kuma watches HTTP/TCP endpoints. |
| View data lineage                                  | **Marquez**                            | Marquez UI (OpenLineage) captures job runs and dataset dependencies emitted by the pipeline.                                                                     |
| Future orchestration (Kubernetes)                  | **Traefik + component modularity**     | The reverse proxy and observability stack can be re-used in Kubernetes; only the runtime provider (Docker vs. K8s) changes.                                      |

## Getting Started

1. **Bootstrap the shared resources**

   ```bash
   ./scripts/bootstrap-control-plane.sh
   ```

   The helper script creates the `data_automation-net` Docker network and the persistent
   volumes required by the control plane and downstream stacks.

2. **Prepare configuration**

    * Create or update the repository level `.env` file with the variables referenced by your
      stacks (host paths, image tags, credentials). Dockge picks up environment overrides from the compose
      definitions under `services/` and `DOCKER_FILES/`.
    * Optionally adjust dashboards and alert rules under `observability/`.

3. **Launch the control plane**

   ```bash
   docker compose up -d traefik dockge grafana prometheus loki promtail uptime-kuma marquez marquez-db
   ```

   Traefik exposes every UI under a single endpoint. When running locally they are available
   at:

   | Application | Path |
      |-------------|------|
   | Traefik dashboard | `http://localhost/traefik` |
   | Dockge | `http://localhost/dockge` |
   | Grafana | `http://localhost/grafana` |
   | Prometheus | `http://localhost/prometheus` |
   | Marquez (data lineage) | `http://localhost/marquez` |
   | Uptime Kuma | `http://localhost/status` |

   Navigating to `/traefik` automatically redirects to the dashboard entry point at
   `/traefik/dashboard/`.

4. **Deploy the data platform stacks**

    * From Dockge, import the compose files in `services/` and `DOCKER_FILES/` to create
      individual stacks for Kafka, Spark, the data generators, and downstream consumers.
    * Start each stack when its dependencies are ready. Dockge presents real-time container
      logs and environment variables for each stack and can trigger rolling restarts when
      configuration changes.

## Working with Logs and Metrics

* **Logs:** Use Grafana's *Explore* view, select the Loki data source, and query by container
  label (e.g. `{container="filewatcher"}`) or compose stack label.
* **Metrics:** Default Prometheus scrape targets include cAdvisor and node exporter. Import
  dashboards from `observability/grafana-provisioning/dashboards` or create custom ones.
* **Alerts:** Provision alert rules through Grafana or Prometheus as needed. Both persist their
  configuration to named Docker volumes so redeployments do not lose state.

## Data Lineage with Marquez

Marquez provides OpenLineage-compatible APIs. The individual services in this monorepo should
emit OpenLineage events (via libraries or sidecars) to populate job runs, datasets, and
lineage graphs. The Marquez UI surfaces the runs, owners, and dependencies to support impact
analysis across the entire pipeline.

## Managing Environment Variables

Dockge allows editing of stack compose files and environment variables via its web UI. For
collaborative workflows, keep authoritative configuration in Git (e.g. compose overrides under
`services/<stack>/docker-compose.yaml`) and apply temporary changes through Dockge when
experimenting. The control plane stores stack definitions under the mounted `/opt/stacks`
volume, making it easy to version the files alongside the repository.

## Future Extensions

* **Kubernetes integration:** Swap Docker as the provider by deploying the same components as
  Helm charts. Traefik, Grafana, Loki, Prometheus, and Marquez all offer official charts and
  can be fronted by a shared ingress controller with identical routes.
* **Secret management:** Integrate HashiCorp Vault or SOPS to centralise sensitive settings.
* **Automated lineage ingestion:** Add OpenLineage SDKs or Airflow/Marquez integrations in the
  data processing services to push lineage metadata continuously.
* **Self-service notebooks:** Attach a JupyterHub stack behind Traefik to give analysts direct
  access to the curated datasets with single sign-on.