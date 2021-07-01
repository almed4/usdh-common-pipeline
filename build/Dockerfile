FROM docker:20.10

VOLUME /var/run/docker.sock /var/run/docker.sock

ENV DOCKER_BUILDKIT=1
ENV DOCKER_CLI_EXPERIMENTAL=1

ARG BUILDX_URL=https://github.com/docker/buildx/releases/download/v0.5.1/buildx-v0.5.1.linux-amd64

RUN mkdir -p $HOME/.docker/cli-plugins && \
    wget -O $HOME/.docker/cli-plugins/docker-buildx $BUILDX_URL && \
    chmod a+x $HOME/.docker/cli-plugins/docker-buildx

COPY script.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]