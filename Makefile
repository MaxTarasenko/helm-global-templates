HELM_CHART_PACKAGE = $(shell ls *.tgz | head -n 1)

DCR = registry-1.docker.io

ifndef HELM_CHART_VERSION
HELM_CHART_VERSION = 0.1.0
endif

diff:
	helm diff test charts/global-one --allow-unreleased

package:
	@helm package charts/global-one --version=$(HELM_CHART_VERSION)

deploy: package
	@helm push $(HELM_CHART_PACKAGE) oci://$(DCR)/mrmerseri
	@rm $(HELM_CHART_PACKAGE)
