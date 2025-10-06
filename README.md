# Automated Data Vault Schema Evolution

This monorepo combines several services to generate synthetic banking data, watch for file
changes, persist records into a data lake and derive a Data Vault model. The repository is
organized as a collection of submodules so each component can be developed independently.

## Architecture

The `DOCU/architecture` submodule contains PlantUML diagrams that document the overall
component and data flow design for the platform.

## Control plane

The repository ships with a fully containerised control plane that centralises lifecycle
management, observability and data lineage for every service. Traefik exposes a unified entry
point (`http://localhost/<app>`) for Dockge (stack orchestration), Grafana and Prometheus
(metrics and dashboards), Loki and Promtail (log aggregation), Uptime Kuma (synthetic
monitoring) and Marquez (OpenLineage powered data lineage).

See `DOCU/control-plane/README.md` for a detailed breakdown of the components, bootstrap
instructions and guidance on how to manage environment variables and deploy future Kubernetes
providers from the same UI.

before starting the controle plane, you have to create the database and user in postgres for the Marquez servive:

````sql
-- create db/user if they don't exist
DO
$$
BEGIN
   IF
NOT EXISTS (SELECT FROM pg_database WHERE datname = 'marquez') THEN
     CREATE
DATABASE marquez;
END IF;
   IF
NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'marquez') THEN
     CREATE
USER marquez WITH PASSWORD 'marquez';
END IF;
END$$;

-- (re)set password in case it was different before)
ALTER
USER marquez WITH PASSWORD 'marquez';

-- ensure ownership/privs
GRANT ALL PRIVILEGES ON DATABASE
marquez TO marquez;
\c
marquez
ALTER
SCHEMA public OWNER TO marquez;
GRANT ALL
ON SCHEMA public TO marquez;
````

## Modules

### `utils/data_generator`

Generates an initial bulk dataset and then continuously appends new records. The initial
generator enumerates required datasets such as customers, accounts and loans and creates any
missing CSV files before writing a completion marker NSERT LINK TO INITIAL_MAIN.
The automator waits for that marker and launches a thread per generator to keep producing
changes INSERT LINK TO MAIN-GENERATOR.MAIN.

### `services/filewatcher`

Scans a directory of CSV files, tracks the last processed row and publishes new rows to
Kafka. An initial crawl is performed on start before handing off to a watchdog observer for
continuous monitoring INSERT LINK TO MAIN.

### `services/datalake_handler`

Consumes the CSV deltas from Kafka using Spark Structured Streaming. Each micro-batch is
flattened and written to the Delta Lake, while a bulk mode drains the topic if streaming
fails or a backlog builds up INSERT LINK TO MAIN.

### `services/data_vault`

Inspects the lake to generate dbt JSON models for hubs, links and satellites, ensures the
target schema exists and then runs dbt while a CDC producer feeds Kafka. A streaming
consumer listens for those events to materialize the Data Vault models INSERT LINK TO MAIN.

### `services/evolution_framework`

TODO!

### `utils/logger`

Reusable logging package that configures colorized output and suppresses noisy dependencies,
exposing a ready-to-use `log` object to other modules INSERT LINK TO MAIN.

## Running the stack

1. Create the shared Docker network (only needed once):

   ```bash
    docker network create data_automation-net
   ```

2. Create the following Docker volumes (only needed once):
   ```bash
    docker volume create delta-jars
    docker volume create ext-jars
    docker volume create jdbc-driver

   ```

3. Supply a `.env` file with the variables referenced in `docker-compose.yaml` (Kafka broker
   ID, Spark image, host data directories, etc.).

4. Launch the entire pipeline:

   ```bash
   docker compose up --build
   ```

The top-level `docker-compose.yaml` aggregates the service-level compose files so the whole
workflow—from synthetic data generation to Data Vault modeling—can be started with a single
command.