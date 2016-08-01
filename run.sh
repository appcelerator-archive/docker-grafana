#!/bin/bash

GRAFANA_BIN=/bin/grafana-server
CONFIG_FILE="/usr/share/grafana/conf/defaults.ini"
CONFIG_OVERRIDE_FILE="/etc/base-config/grafana/defaults.ini"
CONFIG_EXTRA_DIR=/etc/extra-config/grafana
PILOT="/bin/amppilot/amp-pilot.alpine"

if [ -n "${FORCE_HOSTNAME}" ]; then
    if [ "${FORCE_HOSTNAME}" = "auto" ]; then
        #set hostname with IPv4 eth0
        HOSTIPNAME=$(ip a show dev eth0 | grep inet | grep eth0 | tail -1 | sed -e 's/^.*inet.//g' -e 's/\/.*$//g')
        HOSTNAME="$HOSTIPNAME"
    else
        HOSTNAME="$FORCE_HOSTNAME"
    fi
    export HOSTNAME
fi

if [[ -n "$CONFIG_ARCHIVE_URL" ]]; then
  echo "INFO - Download configuration archive file $CONFIG_ARCHIVE_URL..."
  curl -L "$CONFIG_ARCHIVE_URL" -o /tmp/config.tgz
  if [[ $? -eq 0 ]]; then
    tmpd=$(mktemp -d)
    gunzip -c /tmp/config.tgz | tar xf - -C $tmpd
    echo "INFO - Overriding configuration file:"
    find $tmpd/*/base-config/grafana 2>/dev/null
    echo "INFO - Extra configuration file:"
    find $tmpd/*/extra-config/grafana 2>/dev/null
    mv $tmpd/*/extra-config $tmpd/*/base-config /etc/ 2>/dev/null
    rm -rf /tmp/config.tgz "$tmpd"
  else
    echo "WARN - download failed, ignore"
  fi
fi

should_configure=0
for f in $CONFIG_EXTRA_DIR/config-*.js; do
    echo "$f" | grep -q '*' && break
    # look for jinja templates, and convert them
    grep -q "{{ " "$f"
    if [[ $? -eq 0 ]]; then
        echo "converting $f"
        cfg=/etc/grafana/$(basename $f)
        cp "$f" "$cfg.tpl"
        envtpl "$cfg.tpl"
        if [[ $? -ne 0 ]]; then
          echo "ERROR: unable to convert $cfg.tpl"
          exit 1
        fi
    else
        echo "copying $f"
        cp "$f" /etc/grafana/
    fi
    should_configure=1
done
if [[ -f "${CONFIG_OVERRIDE_FILE}" ]]; then
  echo "Override Grafana configuration file"
  cp "${CONFIG_OVERRIDE_FILE}" "${CONFIG_FILE}"
else
  if [[ -f ${CONFIG_FILE}.tpl ]]; then
    envtpl ${CONFIG_FILE}.tpl
    if [[ $? -ne 0 ]]; then
      echo "ERROR: unable to convert $CONFIG_FILE.tpl"
      exit 1
    fi
  elif [[ ! -f ${CONFIG_FILE} ]]; then
    echo "ERROR: no configuration file ${CONFIG_FILE} or ${CONFIG_FILE}.tpl"
    exit 1
  fi
fi

: "${GF_PATHS_DATA:=/var/lib/grafana}"
: "${GF_PATHS_LOGS:=/var/log/grafana}"
: "${GF_PATHS_PLUGINS:=/var/lib/grafana/plugins}"

if [[ ! -x $GRAFANA_BIN ]]; then
  echo "can't find executable at $GRAFANA_BIN"
  exit 1
fi

# using port 3001 instead of 3000 for configuration sake,
# the service won't be up until the real start
API_URL="http://127.0.0.1:3001"
wait_for_start_of_grafana(){
    #wait for the startup of grafana
    local retry=0
    echo "waiting for availability of grafana..."
    while ! curl ${API_URL} 2>/dev/null; do
        retry=$((retry+1))
        if [[ $retry -gt 60 ]]; then
            echo "\nERROR: unable to start grafana"
            exit 1
        fi
        echo -n "."
        sleep 0.2
    done
    echo
}

if [[ -n $GRAFANA_BASE_URL ]]; then
    urlPrefix="${GRAFANA_BASE_URL}/"
else
    urlPrefix=
fi

if [[ $should_configure -eq 1 ]]; then
    echo "Starting grafana for configuration"
    "$GRAFANA_BIN" \
      --homepath=/usr/share/grafana             \
      cfg:default.server.http_addr="127.0.0.1"   \
      cfg:default.server.http_port="3001"   \
      cfg:default.paths.data="$GF_PATHS_DATA"   \
      cfg:default.paths.logs="$GF_PATHS_LOGS"   \
      cfg:default.paths.plugins="$GF_PATHS_PLUGINS" \
      web &
    sleep 0.2
    echo "Checking that grafana is up..."
    ps auwx | grep -q $GRAFANA_BIN || exit 1
    wait_for_start_of_grafana

    echo "configure datasources..."
    for f in /etc/grafana/config-datasource*.js; do
        echo "$f" | grep -q '*' && break
        echo "datasource $f"
        curl -sS "http://$GRAFANA_USER:$GRAFANA_PASS@127.0.0.1:3001/${urlPrefix}api/datasources" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary "@$f"
    done

    echo
    echo "configure dashboards..."
    for f in /etc/grafana/config-dashboard*.js; do
        echo "$f" | grep -q '*' && break
        echo "dashboard $f"
        curl -sS  "http://$GRAFANA_USER:$GRAFANA_PASS@127.0.0.1:3001/${urlPrefix}api/dashboards/db" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary "@$f"
    done
    touch /.ds_is_configured
    echo
    echo "Restarting grafana..."
    killall "$(basename $GRAFANA_BIN)"
else
    echo "no datasource or dashboard json file, skip the configuration step"
fi

echo
CMD="$GRAFANA_BIN"
CMDARGS="--homepath=/usr/share/grafana        \
  cfg:default.paths.data=$GF_PATHS_DATA       \
  cfg:default.paths.logs=$GF_PATHS_LOGS       \
  cfg:default.paths.plugins=$GF_PATHS_PLUGINS \
  web"
if [[ -n "$CONSUL" ]]; then
    i=0
    while [[ ! -x "$PILOT" ]]; do
        echo "WARNING - amp-pilot is not yet available, try again..."
        sleep 1
        ((i++))
        if [[ $i -ge 20 ]]; then
            echo "ERROR - can't find amp-pilot, abort"
            exit 1
        fi
    done
fi
if [[ -n "$CONSUL" && -x "$PILOT" ]]; then
    echo "registering in Consul with $PILOT"
    export AMPPILOT_LAUNCH_CMD="$CMD $CMDARGS"
    export SERVICE_NAME=${SERVICE_NAME:-grafana}
    export AMPPILOT_REGISTEREDPORT=${AMPPILOT_REGISTEREDPORT:-3000}
    export DEPENDENCIES=${DEPENDENCIES:-influxdb}
    exec "$PILOT"
else
    echo "not registering in Consul"
    exec "$CMD" $CMDARGS
fi
