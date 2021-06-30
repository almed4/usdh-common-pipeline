FROM alpine:3.14.0

ARG SECRETS
ENV SECRETS=$SECRETS

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]