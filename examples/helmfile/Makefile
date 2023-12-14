SCRIPT_PATH := "./scripts/helmfile-per-release.sh"
HELMFILE := "./helmfile.yaml"

context:
	@kubectx context-name

diff: context
	$(SCRIPT_PATH) diff $(HELMFILE) env namespace

apply: context
	$(SCRIPT_PATH) apply $(HELMFILE) env namespace

delete: context
	helmfile destroy