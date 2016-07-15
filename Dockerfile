FROM appcelerator/amp:latest
MAINTAINER Nicolas Degory <ndegory@axway.com>

RUN apk --no-cache add nodejs

ENV GRAFANA_VERSION 3.0.4

RUN echo "http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    echo "http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update && apk upgrade && \
    apk --no-cache add fontconfig && \
    apk --virtual build-deps add build-base go curl git gcc musl-dev make nodejs-dev fontconfig-dev && \
    export GOPATH=/go && \
    mkdir -p $GOPATH/src/github.com/grafana && cd $GOPATH/src/github.com/grafana && \
    git clone https://github.com/grafana/grafana.git -b v${GRAFANA_VERSION} &&\
    cd grafana && \
    go run build.go setup && \
    $GOPATH/bin/godep restore && \
    go run build.go build && \
    npm install -g grunt-cli && \
    npm install && \
    npm run build --force && \
    grunt --force && \
    npm uninstall -g grunt-cli && \
    npm cache clear && \
    mv ./bin/grafana-server /bin/ && \
    mkdir -p /etc/grafana/json /var/lib/grafana/plugins /var/log/grafana /usr/share/grafana && \
    mv ./public_gen /usr/share/grafana/public && \
    mv ./conf /usr/share/grafana/conf && \
    apk del build-deps && cd / && rm -rf /var/cache/apk/* $GOPATH

VOLUME ["/var/lib/grafana", "/var/lib/grafana/plugins", "/var/log/grafana"]

EXPOSE 3000

ENV INFLUXDB_HOST localhost
ENV INFLUXDB_PORT 8086
ENV INFLUXDB_PROTO http
ENV INFLUXDB_USER grafana
ENV INFLUXDB_PASS changeme
ENV GRAFANA_USER admin
ENV GRAFANA_PASS changeme
#ENV GRAFANA_BASE_URL

COPY ./grafana.ini /usr/share/grafana/conf/defaults.ini.tpl
COPY ./run.sh /run.sh

ENV SERVICE_NAME=grafana
ENV AMPPILOT_LAUNCH_CMD=/bin/grafana-server
ENV AMPPILOT_REGISTEREDPORT=3000
ENV DEPENDENCIES="influxdb, amp-log-agent"
ENV AMPPILOT_AMPLOGAGENT_ONLYATSTARTUP=true

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/run.sh"]

LABEL axway_image=grafana
# will be updated whenever there's a new commit
LABEL commit=${GIT_COMMIT}
LABEL branch=${GIT_BRANCH}
