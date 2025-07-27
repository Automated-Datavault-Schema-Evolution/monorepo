## Setup

Create custom docker network:

```bash
docker network create data_automation-net
```

Create env-files for Postgres, Kafka and Spark container:
````yaml
# Postgres
POSTGRES_HOST=host.docker.internal
POSTGRES_PORT=5432
POSTGRES_DB=datalake
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
````

````yaml
# Kafka

TODO
````

````yaml
# Spark

TODO

````