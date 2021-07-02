FROM chatwork/helmfile:0.139.9

ARG HELM_VERSION=helm-v3.6.2-linux-amd64.tar.gz
ARG HELM_URL=https://get.helm.sh/$HELM_VERSION
ARG HELM_PATH=/usr/local/bin/helm

RUN wget -O $HELM_VERSION $HELM_URL && \
    tar -zxvf $HELM_VERSION && \
    mv linux-amd64/helm $HELM_PATH && \
    chmod a+x $HELM_PATH

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]