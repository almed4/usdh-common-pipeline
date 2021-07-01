#!/bin/sh -l
set -e

printLargeDelimiter() {
  printf "\n------------------------------------------------------------------------------------------\n\n"
}

printStepExecutionDelimiter() {
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
  printLargeDelimiter

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
  printLargeDelimiter

  VERSION=$([ "$GITHUB_EVENT_NAME" = "release" ] && echo "${GITHUB_REF##*/}" || echo "latest")
  echo "VERSION=$VERSION"
  # shellcheck disable=SC2205
  ACTION=$( ( ( "$GITHUB_EVENT_NAME" == "push" && "$GITHUB_REF" == 'refs/heads/develop' ) || "$GITHUB_EVENT_NAME" == 'release' ) && echo "--push" || echo "--load")
  echo "ACTION=$ACTION"
  IMAGE="$ARTIFACTORY/${GITHUB_REPOSITORY##*/}:$VERSION"
  echo "IMAGE=$IMAGE"
  GIT_PATH="https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY.git#${GITHUB_REF#*/}"
  echo "GIT_PATH=$GIT_PATH"

  echo "Environment populated!"
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

  docker buildx build \
  "$GIT_PATH" \
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

echo "GITHUB_REF: $GITHUB_REF"
echo "GIT_PATH: $GIT_PATH"
echo "GITHUB_ACTOR: $GITHUB_ACTOR"
echo "GITHUB_EVENT_NAME: $GITHUB_EVENT_NAME"
echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
echo "GITHUB_TOKEN: $GITHUB_TOKEN"
echo "GITHUB_REF##*/: ${GITHUB_REF##*/}"
echo "GITHUB_REF#*/: ${GITHUB_REF#*/}"
echo "{GITHUB_REPOSITORY##*/}: ${GITHUB_REPOSITORY##*/}"
#validateEnvironment
#populateEnvironment
#prepDocker
#buildOrPush