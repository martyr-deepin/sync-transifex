FROM hub.deepin.io/golang:1.12-alpine AS builder
WORKDIR /root
COPY src .
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
	apk --no-cache add git
RUN env CGO_ENABLED=0 go build -v -mod=readonly -o app ./cmd/app

FROM daocloud.io/library/debian

MAINTAINER electricface <songwentai@deepin.com>

LABEL Description="sync tansifex for deepin projects"

RUN echo "deb http://pools.corp.deepin.com/deepin panda main contrib non-free" > /etc/apt/sources.list \
    && apt-get update \
    && apt-get -y --allow-unauthenticated install transifex-client git git-review curl jq python3 crudini \
    && apt-get -y --allow-unauthenticated install deepin-gettext-tools \
    && sed -i '$d' /etc/apt/sources.list && apt-get update

# install hub
RUN cd /root \
    && curl -o hub.tgz -L https://github.com/github/hub/releases/download/v2.10.0/hub-linux-amd64-2.10.0.tgz \
    && tar axf hub.tgz \
    && cd hub-linux-* \
    && ./install \
    && cd .. \
    && rm -rf hub.tgz hub-linux-* \
    && hub version

WORKDIR /root
COPY --from=builder /root/app .
ENTRYPOINT ["/root/app"]
