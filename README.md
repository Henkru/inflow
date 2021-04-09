<p align="center">
<img src="docs/inflow.logo.png" alt="Traefik" title="Traefik" />
</p>

Inflow is a housekeeper for InfluxDB [1.x-compatible authorizations](https://docs.influxdata.com/influxdb/v2.0/reference/api/influxdb-1x/#1x-compatible-authorizations) that makes deploying new users and buckets easy. Inflow can be run manually, but it integrates with [Docker Swarm](https://docs.docker.com/engine/swarm/), allowing leverage of [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) to protect the unnecessary exposure of the InfluxDB credentials.

Imagine that you have a stack containing the InfluxDB service, and you want to create a bunch of v1 authorizations when deploying the stack. InfluxDB's Docker image supports custom initialization scripts, which allows you to run a sequence of `influx v1 auth create` commands. However, initialization scripts are only run once during the database setup phase. Therefore they cannot be used for deploying new users or buckets during the run time — inflow is the answer for this problem.

## Features

* Add new v1 users
* Add new buckets with retention rules
* Update the existing buckets

Inflow does not support any deletions operation at the moment. Therefore, removing any users or buckets from a configuration file does not remove them from the Influx database.

## Configuration

Inflow reads the user and bucket information from a YAML file. The complete example configuration is shown below.

```yaml
org: my-org

buckets:
  - name: bucket-1
  - name: bucket-2
    retention: 1h
    description: "lorem ipsum"
users:
  - name: user1
    password: password123
    write:
      - bucket-1
  - name: user2
    password: password123
    write:
      - bucket-1
    read:
      - bucket-1
      - bucket-2
```

## Manual usage

```shell
export INFLUX_HOST=http://localhost:8086
export INFLUX_TOKEN=my-secret-token

./inflow.sh config.yml
```

## Docker Swarm integration

Storing plain text credentials in a config file is not advisable. Therefore, it is recommended to leverage Docker's secrets and template support to pass passwords for inflow, which can be achieved as follows:

```yaml
version: "3.9"

services:
  influxdb:
    image: influxdb:latest
    ports:
      - "8086:8086"
    volumes:
      - $PWD/config.yml:/etc/influxdb2/config.yml
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=user
      - DOCKER_INFLUXDB_INIT_PASSWORD=${INFLUXDB_INIT_PASSWORD}
      - DOCKER_INFLUXDB_INIT_ORG=my-org
      - DOCKER_INFLUXDB_INIT_BUCKET=my-bucket
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${INFLUXDB_INIT_ADMIN_TOKEN}
  inflow:
    image: henkru/inflow:latest
    environment:
      - INFLUX_HOST=http://influxdb:8086
      - INFLUX_TOKEN=${INFLUXDB_INIT_ADMIN_TOKEN}
    configs:
      - source: inflow.config
        target: /conf.d/users.yml
    secrets:
      - user-1
      - user-2

configs:
  inflow.config:
    file: $PWD/inflow.yml
    template_driver: golang

secrets:
  user-1:
    external: true
  user-2:
    external: true
```

The inflow Docker image reads all YAML files under the /conf.d folder, allowing multi-organization support or just dividing the configuration into multiple files. The Docker secrets can be injected into the config file(s) with the help of Docker's template engine, as shown below.

```yaml
org: my-org

buckets:
  - name: bucket-1
  - name: bucket-2
    retention: 1h
    description: "lorem ipsum"
users:
  - name: user1
    password: "{{ secret `user-1` }}"
    write:
      - bucket-1
  - name: user2
    password: "{{ secret `user-2` }}"
    write:
      - bucket-1
    read:
      - bucket-1
      - bucket-2
```

After the stack is deployed, the inflow waits that the InfluxDB instance comes online, and then the buckets and users are created. Inflow exits after all housekeeping tasks are done. So, it does not waste any computing resources by just idling. If you want to add new users to the existing stack, edit the configuration, and then update the inflow service to kick a rerun of the container.
