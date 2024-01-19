# Script
SCRIPT_URL := "https://raw.githubusercontent.com/MaxTarasenko/helm-global-templates/main/scripts/helmfile_per_release.sh"
SCRIPT_PATH := "/tmp/helmfile_per_release.sh"

# Helmfile path
HELMFILE := "./helmfile.yaml"
# if you need
HELMFILE_DEP := "./dependencies.yaml"

# K8s configs
CONTEXT := "context-name"
NAMESPACE := "namespace-name"
# if you need
ENV := "env-name"

# Download and prepare the script
prepare-script:
	curl -o $(SCRIPT_PATH) $(SCRIPT_URL)
	chmod +x $(SCRIPT_PATH)

# Switch to kube context
context:
	@kubectx $(CONTEXT)

diff: context prepare-script
	$(SCRIPT_PATH) diff $(HELMFILE) $(NAMESPACE) $(ENV)
apply: context prepare-script
	$(SCRIPT_PATH) apply $(HELMFILE) $(NAMESPACE) $(ENV)
# or
#diff: context prepare-script
#	$(SCRIPT_PATH) diff $(HELMFILE) $(NAMESPACE)
#apply: context prepare-script
#	$(SCRIPT_PATH) apply $(HELMFILE) $(NAMESPACE)
destroy: context
	helmfile -f $(HELMFILE) -n $(NAMESPACE) destroy

# if you need
diff-dependencies: prepare-script
	$(SCRIPT_PATH) diff $(HELMFILE_DEP) $(NAMESPACE) $(ENV)
apply-dependencies: prepare-script
	$(SCRIPT_PATH) diff $(HELMFILE_DEP) $(NAMESPACE) $(ENV)
# or
#diff-dependencies: prepare-script
#	$(SCRIPT_PATH) diff $(HELMFILE_DEP) $(NAMESPACE) $(ENV)
#apply-dependencies: prepare-script
#	$(SCRIPT_PATH) diff $(HELMFILE_DEP) $(NAMESPACE) $(ENV)
destroy-dependencies: context
	helmfile -f $(HELMFILE_DEP) -n $(NAMESPACE) destroy