FROM daocloud.io/library/debian

MAINTAINER electricface <songwentai@deepin.com>

LABEL Description="sync tansifex for deepin projects"

RUN echo "deb http://mirrors.163.com/debian stretch main" > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y transifex-client git git-review curl jq python3 && echo "deb http://pools.corp.deepin.com/deepin unstable main" >> /etc/apt/sources.list && apt-get update && apt-get -y install deepin-gettext-tools && sed -i '$d' /etc/apt/sources.list && apt-get update

RUN mkdir -p /data /root/.ssh \
    && ssh-keyscan -t rsa -p 29418 cr.deepin.io > ~/.ssh/known_hosts

# source
COPY source /data/transifex

WORKDIR /data/transifex

#CMD ["bash", "-ex", "sync_po.sh"]

