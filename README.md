# Add the repository to Helm
```shell
helm repo add helm-global-templates https://maxtarasenko.github.io/helm-global-templates
helm repo update
```
# Install
```shell
helm install my-release-name helm-global-templates/global-one
```

# Scripts

#### run script (upgrade multiple services)
Environment \
`CHARTS_VALUES_PATH` - global path to values for helm charts \
`NAMESPACE` - namespace \
`CHARTS_VALUE_OVERRIDE` - if the override file exists
```
sh <(curl -sSL https://raw.githubusercontent.com/MaxTarasenko/helm-global-templates/main/scripts/upgrade.sh)
```