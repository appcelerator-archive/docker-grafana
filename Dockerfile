FROM appcelerator/alpine:3.5.2

ENV GRAFANA_VERSION 4.2.0

ENV GOLANG_VERSION 1.8
ENV GOLANG_SRC_URL https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz
ENV GOLANG_SRC_SHA256 406865f587b44be7092f206d73fc1de252600b79b3cacc587b74b5ef5c623596

RUN apk update && apk upgrade && \
    apk --no-cache add fontconfig nodejs && \
    apk --virtual build-deps add build-base go openssl git gcc python musl-dev make nodejs-dev fontconfig-dev && \
    export GOROOT_BOOTSTRAP="$(go env GOROOT)" && \
    wget -q "$GOLANG_SRC_URL" -O golang.tar.gz && \
    echo "$GOLANG_SRC_SHA256  golang.tar.gz" | sha256sum -c - && \
    tar -C /usr/local -xzf golang.tar.gz && \
    rm golang.tar.gz && \
    cd /usr/local/go/src && \
    ./make.bash && \
    export GOPATH=/go && \
    export PATH=/usr/local/go/bin:$PATH && \
    go version && \
    mkdir -p $GOPATH/src/github.com/grafana && cd $GOPATH/src/github.com/grafana && \
    git clone https://github.com/grafana/grafana.git -b v${GRAFANA_VERSION} --depth 1 &&\
    cd grafana && \
    npm install -g yarn@0.19.0 && \
    npm install -g grunt-cli@1.2.0 && \
    go run build.go setup && \
    go run build.go build && \
    yarn install && \
    npm run build && \
    npm uninstall -g yarn && \
    npm uninstall -g grunt-cli && \
    npm cache clear && \
    mv ./bin/grafana-server ./bin/grafana-cli /bin/ && \
    mkdir -p /etc/grafana/json /var/lib/grafana/plugins /var/log/grafana /usr/share/grafana && \
    mv ./public_gen /usr/share/grafana/public && \
    mv ./conf /usr/share/grafana/conf && \
    apk del --purge build-deps build-base nodejs go git && \
    cd / && rm -rf /var/cache/apk/* /usr/local/share/.cache $GOPATH /usr/local/go /go /tmp/* /root/.n*

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
#ENV FORCE_HOSTNAME

COPY ./grafana.ini /usr/share/grafana/conf/defaults.ini.tpl
COPY ./run.sh /run.sh

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/run.sh"]

HEALTHCHECK --interval=5s --retries=5 --timeout=2s CMD curl -u $GRAFANA_USER:$GRAFANA_PASS 127.0.0.1:3000/api/org 2>/dev/null | grep -q '"id":'
