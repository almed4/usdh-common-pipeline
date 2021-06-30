#!/bin/sh -l
set -e
docker="/usr/local/bin/docker"

printLargeDelimeter() {
  printf "\n------------------------------------------------------------------------------------------\n\n"
}

printStepExecutionDelimeter() {
  printf "\n----------------------------------------\n"
}

validateProperty() {
  PROP_KEY=$1
  PROP_VALUE=$(echo "$SECRETS" | grep "$PROP_KEY" | cut -d'=' -f2)
  if [ -z "$PROP_VALUE" ]; then
    echo "Error validating SECRETS: $PROP_VALUE empty."
    return 1
  else
    eval "$PROP_KEY"="$PROP_VALUE"
    return 0
  fi
}

validateEnvironment() {
  printf "\n\nValidating Secrets."
  printLargeDelimeter

  echo "Validating IKEA_ARTIFACTORY_USER_NAME"
  if ! validateProperty "IKEA_ARTIFACTORY_USER_NAME"; then
    return 1
  fi
  echo "Validating IKEA_ARTIFACTORY_PASSWORD"
  if ! validateProperty "IKEA_ARTIFACTORY_PASSWORD"; then
    return 1
  fi

  echo "Secrets validated!"
  return 0
}

populateEnvironment() {
  printf "\n\nPopulating environment."
  printLargeDelimeter

  VERSION=$([ "${GITHUB_EVENT_NAME}" == "release" ] && echo "${GITHUB_REF##*/}" || echo "latest")
  echo "VERSION=$VERSION"
  ACTION=$( ( ( "${GITHUB_EVENT_NAME}" == 'push' && "${GITHUB_REF}" == 'refs/heads/develop' ) || "${GITHUB_EVENT_NAME}" == 'release' ) && echo "--push" || echo "--load")
  echo "ACTION=$ACTION"
  IMAGE="artifactory.build.ingka.ikea.com/ushub-docker-dev-local/${GITHUB_REPOSITORY##*/}:$VERSION"
  echo "IMAGE=$IMAGE"
  PATH="https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git#${GITHUB_REF#*/}"
  echo "PATH=$PATH"

  echo "Environment populated!"
  return 0
}

prepDocker() {
  printf "\n\nPreparing Docker."
  printLargeDelimeter

  echo "Creating buildx"
  $docker buildx create --use \
  --driver docker-container \
  --buildkitd-flags '--allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host'
  echo "buildx created!"

  printStepExecutionDelimeter

  echo "Logging into docker"
  echo "$IKEA_ARTIFACTORY_PASSWORD" |
  $docker login artifactory.build.ingka.ikea.com \
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
  printLargeDelimeter

  $docker buildx build \
  "$PATH" \
  "$ACTION" \
  --platform linux/amd64 \
  --tag "$IMAGE" \
  --cache-from=type=local,src=/tmp/.buildx-cache \
  --cache-to=type=local,dest=/tmp/.buildx-cache,mode=max \
  --build-arg IKEA_ARTIFACTORY_USER_NAME="$IKEA_ARTIFACTORY_USER_NAME" \
  --build-arg IKEA_ARTIFACTORY_PASSWORD="$IKEA_ARTIFACTORY_PASSWORD"
  if [ "$ACTION" = "--push" ]; then
    printf "\n\nDocker image built and pushed to artifactory!"
  else
    printf "\n\nDocker image built!"
  fi

  return 0
}

validateEnvironment
populateEnvironment
prepDocker
buildOrPush