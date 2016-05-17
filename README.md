# Grafana Docker image

This project builds a Docker image with the latest master build of Grafana.

## Running your Grafana container

Start your container binding the external port `3000`.

```
docker run -d --name=grafana -p 3000:3000 appcelerator/grafana
```

Try it out, default admin user is admin/changeme.

## Configuring your Grafana container

All options defined in conf/grafana.ini can be overriden using environment
variables, for example:

```
docker run \
  -d \
  -p 3000:3000 \
  --name=grafana \
  -e "GRAFANA_PASS=changeme" \
  -e "INFLUXDB_HOST=influxdb" \
  -e "INFLUXDB_USER=grafana" \
  -e "INFLUXDB_PASS=changeme" \
  appcelerator/grafana
```

## Grafana container with persistent storage (recommended)

```
# create /var/lib/grafana as persistent volume storage
docker run -d -v /var/lib/grafana --name grafana-storage busybox:latest

# start grafana
docker run \
  -d \
  -p 3000:3000 \
  --name=grafana \
  --volumes-from grafana-storage \
  appcelerator/grafana
```

## Running specific version of Grafana

```
# specify right tag, e.g. 3.0.2 - see Docker Hub for available tags
docker run \
  -d \
  -p 3000:3000 \
  --name grafana \
  appcelerator/grafana:3.0.2
```

# Dashboard and datasources

mount dashboards in /etc/grafana/config-dashboard*.js and datasources in /etc/grafana/config-datasource*.js, they will be loaded at container start.

Default ones are already loaded.


Container pilot
---------------

To enable container pilot, specify the Consul URL:

```docker run -e CONSUL=consul:8500 ...```
