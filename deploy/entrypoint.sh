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
    return 0
  fi
}

validateEnvironment() {
  printLargeDelimiter
  echo "Validating Secrets"
  printDelimiter
  echo "Validating GITHUB_USER"
  if ! validateProperty "GITHUB_USER"; then
    return 1
  fi
  echo "Validating GITHUB_TOKEN"
  if ! validateProperty "GITHUB_TOKEN"; then
    return 1
  fi
  echo "Validating IKEA_ARTIFACTORY_USER_NAME"
  if ! validateProperty "IKEA_ARTIFACTORY_USER_NAME"; then
    return 1
  fi
  echo "Validating IKEA_ARTIFACTORY_PASSWORD"
  if ! validateProperty "IKEA_ARTIFACTORY_PASSWORD"; then
    return 1
  fi
  printStepExecutionDelimiter
  echo "Secrets validated!"
  return 0
}

populateEnvironment() {
  printLargeDelimiter
  echo "Populating environment."
  VERSION=$([ "${GITHUB_EVENT_NAME}" == "release" ] && echo "${GITHUB_REF##*/}" || echo "latest")
  ACTION=$([[ ( "${GITHUB_EVENT_NAME}" == 'push' && "${GITHUB_REF}" == 'refs/heads/develop' ) || "${GITHUB_EVENT_NAME}" == 'release' ]] && echo "--push" || echo "--load")
  IMAGE="artifactory.build.ingka.ikea.com/ushub-docker-dev-local/${GITHUB_REPOSITORY##*/}:$VERSION"
  PATH="https://${{ github.actor }}:${{ github.token }}@github.com/${GITHUB_REPOSITORY}.git#${GITHUB_REF#*/}"
  HELMFILE="https://${{ github.actor }}:${{ github.token }}@raw.githubusercontent.com/${GITHUB_REPOSITORY}/${GITHUB_REF##*/}/helmfile.yaml"
  ENVIRONMENT=$(case ${GITHUB_EVENT_ACTION} in
    released)
      echo 'prod'
    ;;
    prereleased)
      echo 'stage'
    ;;
    *)
      echo 'dev'
    ;;
  esac)
}

validateEnvironment
populateEnvironment
