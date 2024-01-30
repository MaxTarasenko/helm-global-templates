HELM_CHART_PACKAGE = $(shell ls *.tgz | head -n 1)

DCR = registry-1.docker.io

ifndef HELM_CHART_VERSION
HELM_CHART_VERSION = 0.1.6
endif

login:
	helm registry login registry-1.docker.io

create-namespace:
	kubectl create namespace test

diff:
	helm -n test diff upgrade test charts/global-one --allow-unreleased --context 1 --debug

upgrade_or_install:
	helm -n test upgrade --install test charts/global-one

package:
	@helm package charts/global-one --version=$(HELM_CHART_VERSION)

deploy: package
	@helm push $(HELM_CHART_PACKAGE) oci://$(DCR)/mrmerseri
	@rm $(HELM_CHART_PACKAGE)
