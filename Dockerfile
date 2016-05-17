FROM alpine:3.3
MAINTAINER Nicolas Degory <ndegory@axway.com>

RUN apk update && \
    apk --no-cache add python ca-certificates && \
    apk --virtual envtpl-deps add --update py-pip python-dev curl && \
    curl https://bootstrap.pypa.io/ez_setup.py | python && \
    pip install envtpl && \
    apk del envtpl-deps && rm -rf /var/cache/apk/*

RUN apk --no-cache add nodejs

ENV GRAFANA_VERSION 3.0.2

ADD package.json /tmp/package.json

RUN echo "http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    echo "http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update && apk upgrade && \
    apk --virtual build-deps add build-base go curl git gcc musl-dev make nodejs-dev && \
    export GOPATH=/go && \
    mkdir -p $GOPATH/src/github.com/grafana && cd $GOPATH/src/github.com/grafana && \
    git clone https://github.com/grafana/grafana.git -b v${GRAFANA_VERSION} &&\
    cd grafana && \
    go run build.go setup && \
    $GOPATH/bin/godep restore && \
    go run build.go build && \
    npm install && \
    npm run build && \
    npm install -g grunt-cli && \
    grunt && \
    npm uninstall -g grunt-cli && \
    npm cache clear && \
    mv ./bin/grafana-server /bin/ && \
    mkdir -p /etc/grafana /var/lib/grafana/plugins /var/log/grafana /usr/share/grafana && \
    mv ./public_gen /usr/share/grafana/public && \
    mv ./conf /usr/share/grafana/conf && \
    apk del build-deps && cd / && rm -rf /var/cache/apk/* $GOPATH

RUN apk --no-cache add curl bash

VOLUME ["/var/lib/grafana", "/var/lib/grafana/plugins", "/var/log/grafana", "/etc/grafana"]

EXPOSE 3000

ENV INFLUXDB_HOST localhost
ENV INFLUXDB_PORT 8086
ENV INFLUXDB_PROTO http
ENV INFLUXDB_USER grafana
ENV INFLUXDB_PASS changeme
ENV GRAFANA_USER admin
ENV GRAFANA_PASS changeme

COPY ./grafana.ini /usr/share/grafana/conf/defaults.ini.tpl
COPY ./config-*.js /etc/grafana/
COPY ./run.sh /run.sh

# Add ContainerPilot
ENV CONTAINERPILOT=2.1.0
RUN curl -Lo /tmp/cb.tar.gz https://github.com/joyent/containerpilot/releases/download/$CONTAINERPILOT/containerpilot-$CONTAINERPILOT.tar.gz \
&& tar -xz -f /tmp/cb.tar.gz \
&& mv ./containerpilot /bin/
COPY containerpilot.json /etc/containerpilot.json
COPY ./start.sh /start.sh
COPY ./stop.sh /stop.sh
RUN chmod +x /*.sh

#ENV CONSUL=consul:8500
ENV CONTAINERPILOT=file:///etc/containerpilot.json
ENV DEPENDENCIES=influxdb

CMD ["/start.sh"]

LABEL axway_image=grafana
# will be updated whenever there's a new commit
LABEL commit=${GIT_COMMIT}
LABEL branch=${GIT_BRANCH}
