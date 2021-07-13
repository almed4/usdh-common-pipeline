# usdh-common-pipeline

GitHub actions for building and releasing USDH applications.

## [Docker Build or Push](https://github.com/almed4/usdh-common-pipeline/tree/main/docker-build)

This pipeline will retrieve Artifactory secrets from Vault using the provided Vault token. It will
then execute a docker build or docker push using the Dockerfile depending on the type of trigger
for the action.

## [Helmfile Deploy](https://github.com/almed4/usdh-common-pipeline/tree/main/helm-deploy)

This pipeline will retrieve image pull secrets and GitHub credentials to access 
[usd-common-helm](https://github.com/ingka-group-digital/usdh-common-helm) then execute hemfile
-e <ENVIRONMENT> sync.

# Contributing

```shell
git commit -m "My changes"
git tag -a -m "My release" v1.x.x
git push --follow-tags
```