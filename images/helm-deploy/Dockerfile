FROM chatwork/helmfile:0.139.9

ARG VAULT_VERSION=vault_1.7.3_linux_amd64.zip
ARG VAULT_URL=https://releases.hashicorp.com/vault/1.7.3/vault_1.7.3_linux_amd64.zip
ARG VAULT_PATH=/usr/local/bin/vault

ARG HELM_VERSION=helm-v3.6.2-linux-amd64.tar.gz
ARG HELM_URL=https://get.helm.sh/$HELM_VERSION
ARG HELM_PATH=/usr/local/bin/helm

RUN wget -O $VAULT_VERSION $VAULT_URL && \
    unzip $VAULT_VERSION && \
    mv vault $VAULT_PATH

RUN wget -O $HELM_VERSION $HELM_URL && \
    tar -zxvf $HELM_VERSION && \
    mv linux-amd64/helm $HELM_PATH && \
    chmod a+x $HELM_PATH