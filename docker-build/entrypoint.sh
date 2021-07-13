#!/bin/sh -l
set -e

printLargeDelimiter() {
  printf "\n------------------------------------------------------------------------------------------\n\n"
}

printStepExecutionDelimiter() {
  printf "\n----------------------------------------\n"
}

populateEnvironment() {
  printf "\n\nPopulating environment."
  printLargeDelimiter

  VERSION=$([ "$GITHUB_EVENT_NAME" = "release" ] && echo "${GITHUB_REF##*/}" || echo "latest")
  echo "VERSION=$VERSION"
  # shellcheck disable=SC2205
  ACTION=$( { { [ "$GITHUB_EVENT_NAME" = "push" ] && [ "$GITHUB_REF" = "refs/heads/develop" ]; } || [ "$GITHUB_EVENT_NAME" = "release" ]; } && echo "--push" || echo "--load")
  echo "ACTION=$ACTION"
  IMAGE="$ARTIFACTORY/${GITHUB_REPOSITORY##*/}:$VERSION"
  echo "IMAGE=$IMAGE"
  GIT_PATH="https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY.git#${GITHUB_REF#*/}"
  echo "GIT_PATH=$GIT_PATH"

  export ACTION
  export IMAGE
  export GIT_PATH

  echo "Environment populated!"
  return 0
}

getSecrets() {
  printf "\n\nPreparing Secrets."
  printLargeDelimiter

  IKEA_ARTIFACTORY_USER_NAME=$(vault kv get \
    -address="https://vault-prod.build.ingka.ikea.com/" \
    -namespace="runtime-terrors" \
    -field=username \
    kv/artifactory)
  echo "Artifactory username downloaded!"

  IKEA_ARTIFACTORY_PASSWORD=$(vault kv get \
    -address="https://vault-prod.build.ingka.ikea.com/" \
    -namespace="runtime-terrors" \
    -field=password \
    kv/artifactory)
  echo "Artifactory password downloaded!"

  export IKEA_ARTIFACTORY_USER_NAME
  export IKEA_ARTIFACTORY_PASSWORD

  echo "Secrets prepared!"
  return 0
}

prepDocker() {
  printf "\n\nPreparing Docker."
  printLargeDelimiter

  echo "Creating buildx."
  docker buildx create --use \
  --driver docker-container \
  --buildkitd-flags '--allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host'
  echo "buildx created!"

  printStepExecutionDelimiter

  echo "Logging into docker."
  echo "$IKEA_ARTIFACTORY_PASSWORD" |
  docker login artifactory.build.ingka.ikea.com \
  --username "$IKEA_ARTIFACTORY_USER_NAME" \
  --password-stdin
  echo "Logged into docker!"

  return 0
}

buildOrPush() {
  if [ "$ACTION" = "--push" ]; then
    printf "\n\nBuilding and pushing docker image."
  else
    printf "\n\nBuilding docker image."
  fi
  printLargeDelimiter

  if [ -z "$CACHE" ]; then
    CACHE="."
  fi

  docker buildx build \
    "$GIT_PATH" \
    "$ACTION" \
    --tag "$IMAGE" \
    --platform linux/amd64 \
    --cache-from=type=local,src="$CACHE" \
    --cache-to=type=local,dest="$CACHE",mode=max \
    --build-arg IKEA_ARTIFACTORY_USER_NAME="$IKEA_ARTIFACTORY_USER_NAME" \
    --build-arg IKEA_ARTIFACTORY_PASSWORD="$IKEA_ARTIFACTORY_PASSWORD"

  if [ "$ACTION" = "--push" ]; then
    printf "\n\nDocker image built and pushed to artifactory!"
  else
    printf "\n\nDocker image built!"
  fi

  return 0
}

getSecrets
populateEnvironment
prepDocker
buildOrPush