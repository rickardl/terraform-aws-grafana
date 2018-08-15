OS=darwin
DIR=$(shell pwd)


##
# TERRAFORM INSTALL
##
version  ?= "0.11.7"
os       ?= $(shell uname|tr A-Z a-z)
ifeq ($(shell uname -m),x86_64)
  arch   ?= "amd64"
endif
ifeq ($(shell uname -m),i686)
  arch   ?= "386"
endif
ifeq ($(shell uname -m),aarch64)
  arch   ?= "arm"
endif

##
# INTERNAL VARIABLES
##
# Read all subsquent tasks as arguments of the first task
RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(args) $(RUN_ARGS):;@:)
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
landscape   := $(shell command -v landscape 2> /dev/null)
terraform   := $(shell command -v terraform 2> /dev/null)


.PHONY: test
default: test

.PHONY: install
install: ## Install terraform and dependencies
ifeq ($(install),"true")
	@wget -O /usr/bin/terraform.zip https://releases.hashicorp.com/terraform/$(version)/terraform_$(version)_$(os)_$(arch).zip
	@unzip -d /usr/bin /usr/bin/terraform.zip && rm /usr/bin/terraform.zip
endif
	@terraform --version
	@bash $(dir $(mkfile_path))/terraform.sh init

.PHONY: fmt
fmt:
	@terraform fmt $(args) $(RUN_ARGS)

.PHONY: lint
lint: ## Rewrites config to canonical format
	@terraform fmt -diff=true -check $(args) $(RUN_ARGS
	@tflint 

.PHONY: validate
validate: ## Basic syntax check
	@bash $(dir $(mkfile_path))/terraform.sh validate $(args) $(RUN_ARGS)

.PHONY: update
update: ## Gets any module updates
	@terraform get -update=true &>/dev/null

.PHONY: test
test:
	@echo "== Test =="
	@if ! terraform fmt -write=false -check=true >> /dev/null; then \
		echo "✗ terraform fmt failed: $$d"; \
		exit 1; \
	else \
		echo "√ terraform fmt"; \
	fi

	@for d in $$(find . -type f -name '*.tf' -path "./modules/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
		cd $$d; \
		terraform init -backend=false >> /dev/null; \
		terraform validate -check-variables=false; \
		if [ $$? -eq 1 ]; then \
			echo "✗ terraform validate failed: $$d"; \
			exit 1; \
		fi; \
		cd $(DIR); \
	done
	@echo "√ terraform validate modules (not including variables)"; \

	@for d in $$(find . -type f -name '*.tf' -path "./examples/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
		cd $$d; \
		terraform init -backend=false >> /dev/null; \
		terraform validate; \
		if [ $$? -eq 1 ]; then \
			echo "✗ terraform validate failed: $$d"; \
			exit 1; \
		fi; \
		cd $(DIR); \
	done
	@echo "√ terraform validate examples"; \


validate-terraform-version:
	@if [ "$(TERRAFORM_VERSION)" != "$(TERRAFORM_PINNED_VERSION)" ]; then \
		echo "ERROR: Detected Terraform version ($(TERRAFORM_VERSION)) does not match the pinned version ($(TERRAFORM_PINNED_VERSION))" >&2 ; \
		exit 1 ; \
	fi

validate: validate-terraform-version
