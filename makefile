#! /usr/bin/make -f

-include makefile.config
-include makefile.config.local

SHELL := /bin/bash -O globstar

.PHONY: clean default debug_operator_sdk operator_sdkd_manifests personalize_kustomizations purge test_yaml venv

default: test_yaml

tolower = $(shell echo $(1) | tr '[:upper:]' '[:lower:]')

APIS = Category Tag TagManager

CRDS = $(call tolower $(patsubst config/crd/bases/%.yaml, %, $(APIS)))

crds: $(CRDS)
	@echo -n "Creating $@ with container: "
	@$(eval RAND := $(shell /bin/bash -c "echo $$RANDOM"))
	@mkdir --parents "$(@D)"
	@# TODO - privileged=true because otherwise clone3 is blocked by seccomp, at least it is on RHEL8
	@# due to missing entry in /usr/share/containers/seccomp.json
	@docker create \
		--name=$(operator_sdk_name)-$(RAND) \
		--rm=true \
		--tty=true \
		--volume="$(shell pwd -P)/config:/config:rw,Z" \
		$(operator_sdk_registry)/$(operator_sdk_namespace)/$(operator_sdk_image):$(operator_sdk_tag) \
		operator-sdk ""
	@docker cp src $(operator_sdk_name)-$(RAND):/home/argocd/src
	@echo "# This is an auto-generated file. DO NOT EDIT" > "$@"
	@docker start --attach=true $(operator_sdk_name)-$(RAND) | sed 's/\r$$//' >> "$@"

test_yaml:
	.venv/bin/python -m yamllint .

.venv:
	python -m venv .venv
	.venv/bin/python -m pip install --upgrade pip
	.venv/bin/python -m pip install yamllint

venv: .venv

clean:
	@rm --force --recursive .venv

purge: clean
	@rm --force $(shell ls **/operator_sdkd-manifest.yaml)
