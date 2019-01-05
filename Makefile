.PHONY: build

PROJECT_NAME ?= "gcis-graphql"

AWS_REGION ?= "ap-northeast-1"
CFN_STACK_NAME ?= $(PROJECT_NAME)
CFN_BUCKET_NAME ?= $(PROJECT_NAME)-bucket
CFN_TEMPLATE := "./template.yml"
CFN_PACKAGED_TEMPLATE := "./build/packaged.yml"
CFN_BUILD_DIR := $(shell dirname $(CFN_PACKAGED_TEMPLATE))
CFN_PARAMETER_FILE ?= ""
CFN_PARAMETER_OVERRIDES := $(if $(CFN_PARAMETER_FILE:""=),--parameter-overrides $(shell jq -j '.[] | "\"" + .ParameterKey + "=" + .ParameterValue +"\" "' $(CFN_PARAMETER_FILE)),)
GOOS := linux

TMP_MSG := ".tmpmsg"
TMP_RET := ".tmpret"

print_target = echo "\033[1;36m == $@ == \033[0m\n"
print_msg = echo "\033[$(1)m$(2)\033[0m\n"
check_dependency = $(if $(shell command -v $(1) 2> /dev/null),,$(error Make sure $(1) is installed))

help:
	@echo "\nUsage: $ make COMMAND\n\nCommands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'

check-required-tools:
	@$(call print_target)
	@$(call check_dependency,aws)
	@$(call check_dependency,cfn-lint)
	@$(call check_dependency,dep)
	@$(call check_dependency,golangci-lint)
	@$(call check_dependency,jq)
	@$(call check_dependency,cfn_nag)
	@echo "√ Pass"

install: ## Install required tools
	pip install --user awscli cfn-lint
	gem install cfn-nag
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $$(go env GOPATH)/bin v1.12.5
	curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
	@make check-required-tools

clean: ## Clean all artifacts
	@$(call print_target)
	rm -rf $(CFN_BUILD_DIR)
	rm -rf $(TMP_MSG)
	rm -rf $(TMP_RET)

deps: ## Install the lambda's dependencies
	@$(call print_target)
	dep ensure -v

lint: ## Run all Go linters
	@$(call print_target)
	@golangci-lint run -E gofmt ./cmd ./internal/... && echo "√ golangci-lint" || exit 1

build:lint ## Build the lambda binary
	@$(call print_target)
	@ GOOS=$(GOOS) go build -ldflags="-s -w" -o $(CFN_BUILD_DIR)/handler cmd/main.go

cfn-lint:
	@$(call print_target)
	@cfn-lint -t $(CFN_TEMPLATE) && echo "√ $(CFN_TEMPLATE)" || exit 1

cfn-nag:
	@$(call print_target)
	@cfn_nag_scan --input-path=$(CFN_TEMPLATE) --allow-suppression

cfn-test:cfn-lint cfn-nag ## Check the CloudFormation template

cfn-validate:cfn-test
	@$(call print_target)
	aws cloudformation validate-template --template-body file://$(CFN_TEMPLATE)

cfn-package:cfn-validate
	@$(call print_target)
	@mkdir -p $(CFN_BUILD_DIR)
	aws cloudformation package \
		--template-file $(CFN_TEMPLATE) \
		--output-template-file $(CFN_PACKAGED_TEMPLATE) \
		--s3-bucket $(CFN_BUCKET_NAME) \
		--s3-prefix cfn-templates \
		--region $(AWS_REGION)

cfn-changeset:cfn-package ## Create a change list of stack
	@$(call print_target)
	@$$((aws cloudformation deploy \
		--stack-name $(CFN_STACK_NAME) \
		--template-file $(CFN_PACKAGED_TEMPLATE) \
		--no-execute-changeset \
		$(CFN_PARAMETER_OVERRIDES) \
		--capabilities CAPABILITY_NAMED_IAM \
		--region $(AWS_REGION) \
		1> $(TMP_MSG) 2>&1); echo $${PIPESTATUS[0]} > $(TMP_RET))
	@# Check return code and msg. If no changeset, cfn deploy will return 255 with msg "No changes to deploy"
	@if [ $$(cat $(TMP_RET)) -eq 0 ]; then \
		cat $(TMP_MSG); \
		echo ""; \
		$(call print_msg,3," === List stack changeset for stack $(CFN_STACKNAME) ==="); \
		$$(cat $(TMP_MSG) | grep "aws cloudformation") | jq -r '.Changes[]|.ResourceChange.Action + "\t" + .ResourceChange.ResourceType + "     \t" + .ResourceChange.LogicalResourceId + "   \t["+.ResourceChange.PhysicalResourceId + "]"';  \
	elif [ $$(cat $(TMP_RET)) -eq 255 ] && grep -qF "No changes to deploy" $(TMP_MSG) ; then \
		cat $(TMP_MSG); \
		exit 0; \
	else \
		$(call print_msg,1," === Error !!! ==="); \
		cat $(TMP_MSG); \
		exit $$(cat $(TMP_RET)); \
	fi

package:build cfn-package ## Package the local artifacts

deploy:package ## Deploy to AWS
	@$(call print_target)
	aws cloudformation deploy \
		--stack-name $(CFN_STACK_NAME) \
		--template-file $(CFN_PACKAGED_TEMPLATE) \
		$(CFN_PARAMETER_OVERRIDES) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset \
		--region $(AWS_REGION)

describe: ## Return the stack description
	@$(call print_target)
	aws cloudformation describe-stacks \
		--stack-name $(CFN_STACK_NAME) \
		--region $(AWS_REGION)
