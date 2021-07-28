#!/bin/sh -l
set -e

printLargeDelimiter() {
  printf "\n------------------------------------------------------------------------------------------\n\n"
}

printStepExecutionDelimiter() {
  printf "\n----------------------------------------\n"
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

  GITHUB_ACTOR=$(vault kv get \
    -address="https://vault-prod.build.ingka.ikea.com/" \
    -namespace="runtime-terrors" \
    -field=username \
    kv/github)
  echo "GitHub actor downloaded!"

  GITHUB_TOKEN=$(vault kv get \
    -address="https://vault-prod.build.ingka.ikea.com/" \
    -namespace="runtime-terrors" \
    -field=token \
    kv/github)
  echo "GitHub token downloaded!"

  export IKEA_ARTIFACTORY_USER_NAME
  export IKEA_ARTIFACTORY_PASSWORD
  export GITHUB_ACTOR
  export GITHUB_TOKEN

  echo "Secrets prepared!"
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

syncHelmfile() {
  printf "\n\nSyncing Helmfile."
  printLargeDelimiter

  helmfile -e "$ENVIRONMENT" sync

  echo "Helmfile synced!"
  return 0
}

getKubeSA() {
  KUBE_SA=$(kubectl get ikeasink -o=jsonpath='{.items[0].status.create_sink.sa}')
  BUCKET=$(kubectl get ikeasink -o=jsonpath='{.items[0].spec.bucketname}')
  GCP_PROJECT=$(kubectl get ikeasink -o=jsonpath='{.items[0].spec.project}')

  GCLOUD_TOKEN=$(vault read \
    -address="https://vault-prod.build.ingka.ikea.com/" \
    -namespace="runtime-terrors" \
    -field=token \
    gcp/token/"$GCP_PROJECT")
  GCLOUD_AUTH_HEADER="Authorization: Bearer $GCLOUD_TOKEN"

  export KUBE_SA
  export BUCKET
  export GCP_PROJECT

  export GCLOUD_AUTH_HEADER

  echo "Retrieved IkeaSink Service Account!"
  return 0
}

makeGcpRequest() {
  curl -X POST -L -s "https://$1" \
    -H "$GCLOUD_AUTH_HEADER" \
    -H "Content-Type: application/json" \
    --data-raw "$2" \
    2>/dev/null > tmp.json

  if grep error < tmp.json 1>/dev/null; then
    echo "Error sending API request to $GCP_PROJECT:"
    echo "    \"uri\": \"https://$1\""
    echo "    \"body\": \"$2\""
    grep message < tmp.json
  fi
}

createLogBucket() {
  printf "\n\nCreating Log Bucket."
  printLargeDelimiter

  RETENTION=$( [ "$ENVIRONMENT" = "prod" ] && echo "365" || echo "90")
  json="{\"name\":\"$BUCKET\",\"description\":\"Logs forwarded from gke-managed cluster\",\"retentionDays\":$RETENTION,\"locked\":false}"
  makeGcpRequest "logging.googleapis.com/v2/projects/$GCP_PROJECT/locations/global/buckets?bucketId=$BUCKET" "$json"
  echo "Created log bucket $BUCKET in $GCP_PROJECT!"
  return 0
}

bindRoles() {
  printf "\n\nBinding IkeaSink service account."
  printLargeDelimiter

  json="{\"options\":{\"requestedPolicyVersion\":1}}"
  makeGcpRequest "cloudresourcemanager.googleapis.com/v1/projects/$GCP_PROJECT:getIamPolicy" "$json"
  sed -i.bak '$d' tmp.json
  sed -i.bak '$d' tmp.json
  echo ",{\"role\":\"roles/logging.bucketWriter\",\"members\":[\"serviceAccount:$KUBE_SA\"]}]}" >> tmp.json
  makeGcpRequest "cloudresourcemanager.googleapis.com/v1/projects/$GCP_PROJECT:setIamPolicy" "{\"policy\":$(cat tmp.json)}"
  echo "Bound roles between IkeaSink in MGKE $ENVIRONMENT and $GCP_PROJECT!"
  return 0
}

# Sync helmfile
getSecrets
populateEnvironment
prepHelmEnvironment
syncHelmfile

# Setup logging
set +e
getKubeSA
createLogBucket
bindRoles

printLargeDelimiter
printf "\n\nApplication Deployed!.\n\n"
printLargeDelimiter
