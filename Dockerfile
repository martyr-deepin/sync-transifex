FROM debian

MAINTAINER tangcaijun <choldrim@foxmail.com>

LABEL Description="sync tansifex for deepin projects"

RUN echo "deb http://pools.corp.deepin.com/deepin unstable main contrib non-free" > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --force-yes transifex-client git git-review curl jq

RUN mkdir -p /data /root/.ssh \
    && ssh-keyscan -t rsa -p 29418 cr.deepin.io > ~/.ssh/known_hosts

# source
COPY source /data/transifex

WORKDIR /data/transifex

#CMD ["bash", "-ex", "sync_po.sh"]

