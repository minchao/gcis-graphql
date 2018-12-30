.PHONY: build

PROJECT_NAME ?= "gcis-graphql"

AWS_REGION ?= "ap-northeast-1"
CFN_STACK_NAME ?= $(PROJECT_NAME)
CFN_BUCKET_NAME ?= $(PROJECT_NAME)-bucket
CFN_TEMPLATE := "./cloudformation/template.yml"
CFN_TEMPLATE_DIR = $(shell dirname $(CFN_TEMPLATE))
CFN_PACKAGED_TEMPLATE := "./build/packaged.yml"
CFN_PARAMETER_FILE ?= ""
CFN_PARAMETER_OVERRIDES := $(if $(CFN_PARAMETER_FILE:""=),--parameter-overrides $(shell jq -j '.[] | "\"" + .ParameterKey + "=" + .ParameterValue +"\" "' $(CFN_PARAMETER_FILE)),)
GOOS := linux

TMP_MSG := ".tmpmsg"
TMP_RET := ".tmpret"

print_target = echo "$(shell tput bold;tput setaf 2 ) == $@ == $(shell tput sgr0)"
print_msg = echo "$(shell tput setaf $(1))$(2)$(shell tput sgr0)"
check_dependency = $(if $(shell command -v $(1) 2> /dev/null),,$(error Make sure $(1) is installed))

install:
	pip install --user awscli cfn-lint
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(TRAVIS_HOME)/.local/bin v1.12.5
	curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

clean:
	@$(call print_target)
	rm -rf ./build
	rm -rf $(TMP_MSG)
	rm -rf $(TMP_RET)

check-required-tools:
	@$(call print_target)
	@$(call check_dependency,aws)
	@$(call check_dependency,cfn-lint)
	@$(call check_dependency,dep)
	@$(call check_dependency,golangci-lint)
	@$(call check_dependency,jq)
	@$(call check_dependency,tput)
	@echo "√ Pass"

deps:
	@$(call print_target)
	dep ensure -v

lint:
	@$(call print_target)
	@golangci-lint run -E gofmt ./cmd && echo "√ golangci-lint" || exit 1

build:lint
	@$(call print_target)
	@ GOOS=$(GOOS) go build -ldflags="-s -w" -o build/handler cmd/main.go

cfn-lint:
	@$(call print_target)
	@cfn-lint -t $(CFN_TEMPLATE) && echo "√ $(CFN_TEMPLATE)" || exit 1

cfn-validate:cfn-lint
	@$(call print_target)
	@find $(CFN_TEMPLATE_DIR) -type f \( -name "*.yaml" -or -name "*.yml" \) | \
		while read f; do \
		( aws cloudformation validate-template --template-body file://$$f 1>/dev/null 2> $(TMP_MSG) && echo "√ $$f") || \
		( echo "✗ $$f" && cat $(TMP_MSG) && >$(TMP_MSG) && exit 1 ) ; done

cfn-package:cfn-validate
	@$(call print_target)
	aws cloudformation package \
		--template-file $(CFN_TEMPLATE) \
		--output-template-file $(CFN_PACKAGED_TEMPLATE) \
		--s3-bucket $(CFN_BUCKET_NAME) \
		--s3-prefix cfn-templates \
		--region $(AWS_REGION)

cfn-changeset:cfn-package
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

deploy:build cfn-package
	aws cloudformation deploy \
		--stack-name $(CFN_STACK_NAME) \
		--template-file $(CFN_PACKAGED_TEMPLATE) \
		$(CFN_PARAMETER_OVERRIDES) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset \
		--region $(AWS_REGION)

describe:
	@$(call print_target)
	aws cloudformation describe-stacks \
		--stack-name $(CFN_STACK_NAME) \
		--region $(AWS_REGION)
