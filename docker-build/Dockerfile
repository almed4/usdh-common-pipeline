FROM docker:20.10

ENV DOCKER_BUILDKIT=1
ENV DOCKER_CLI_EXPERIMENTAL=1

ENV VAULT_TOKEN=$VAULT_TOKEN

ARG BUILDX_URL=https://github.com/docker/buildx/releases/download/v0.5.1/buildx-v0.5.1.linux-amd64

ARG VAULT_VERSION=vault_1.7.3_linux_amd64.zip
ARG VAULT_URL=https://releases.hashicorp.com/vault/1.7.3/vault_1.7.3_linux_amd64.zip
ARG VAULT_PATH=/usr/local/bin/vault

RUN mkdir -p $HOME/.docker/cli-plugins && \
    wget -O $HOME/.docker/cli-plugins/docker-buildx $BUILDX_URL && \
    chmod a+x $HOME/.docker/cli-plugins/docker-buildx

RUN wget -O $VAULT_VERSION $VAULT_URL && \
    unzip $VAULT_VERSION && \
    mv vault $VAULT_PATH

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]