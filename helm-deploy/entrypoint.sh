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
    eval export "$PROP_KEY"="$PROP_VALUE"
    return 0
  fi
}

validateEnvironment() {
  printf "\n\nValidating Secrets."
  printLargeDelimiter

  echo "Validating GITHUB_ACTOR"
  if ! validateProperty "GITHUB_ACTOR"; then
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

  echo "Secrets validated!"
  return 0
}

populateEnvironment() {
  printf "\n\nPopulating environment."
  printLargeDelimiter

  VERSION=$([ "$GITHUB_EVENT_NAME" = "release" ] && echo "${GITHUB_REF##*/}" || echo "latest")
  echo "VERSION=$VERSION"
  export IMAGE="artifactory.build.ingka.ikea.com/ushub-docker-dev-local/${GITHUB_REPOSITORY##*/}:$VERSION"
  echo "IMAGE=$IMAGE"
  HELMFILE="https://$GITHUB_ACTOR:$GITHUB_TOKEN@raw.githubusercontent.com/$GITHUB_REPOSITORY/${GITHUB_REF##*/}/helmfile.yaml"
  echo "HELMFILE=***@$(echo "HELMFILE=$HELMFILE" | sed "s/.*@//")"
  ENVIRONMENT=$(case "$GITHUB_EVENT_ACTION" in
    "released")
      echo 'prod'
      ;;
    "prereleased")
      echo 'stage'
      ;;
    *)
      echo 'dev'
      ;;
    esac)
  echo "ENVIRONMENT=$ENVIRONMENT"
  export ENVIRONMENT

  echo "Environment populated!"
  return 0
}

prepHelmEnvironment() {
  printf "\n\nPreparing Helm environment."
  printLargeDelimiter

  mkdir ~/.kube
  echo "$KUBECONFIG" >>~/.kube/config
  chmod 400 ~/.kube/config
  unset KUBECONFIG
  echo "KUBECONFIG created."

  HELM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$HELMFILE") # | sed ':a;N;$!ba;s/\n//g')
  if [ "$HELM_RESPONSE" = "200" ]; then
    curl -s "$HELMFILE" >>helmfile.yaml
  else
    echo "Error retrieving Helmfile: $HELM_RESPONSE"
    return 1
  fi

  echo "Helm environment prepared!"
  return 0
}

# This step must be completed because Helmfile doesn't have support for
# --pass-credentials, which is necessary to pull from our repo (and Helm-Git
# doesn't work with versioned charts)
#
# Hopefully fixed by: https://github.com/roboll/helmfile/issues/1898
addHelmRepo() {
  printf "\n\nAdding Helm repository."
  printLargeDelimiter

  helm repo add \
    --username "$GITHUB_ACTOR" \
    --password "$GITHUB_TOKEN" \
    --pass-credentials \
    usdh-common-helm \
    https://raw.githubusercontent.com/ingka-group-digital/usdh-common-helm/prod/repo

  echo "Helm repo added!"
  return 0
}

syncHelmfile() {
  printf "\n\nSyncing Helmfile."
  printLargeDelimiter

  helmfile -e "$ENVIRONMENT" sync

  echo "Helmfile synced!"
  return 0
}

validateEnvironment
populateEnvironment
prepHelmEnvironment
addHelmRepo
syncHelmfile

printLargeDelimiter
printf "\n\nApplication Deployed!.\n\n"
printLargeDelimiter
