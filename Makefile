# make file to build Dockerfile image

include .env
export MAIN_TAG MAIN_CO_BRANCH DKR_IMAGE_TAG

# get Makefile's directory
DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# exit Makefile with error if DIR is not set, and does not end with litellm-cyverse
ifeq ($(DIR),)
$(error DIR is not set)
endif

ifneq ($(findstring litellm-docker,$(DIR)),litellm-docker)
$(error DIR must contain "litellm-docker" (got "$(DIR)") )
endif

# DKR_IMAGE_TAG := v1.67.4-stable-20250515

.PHONY: build run

# build litellm container with patch
build:
	docker build \
	--build-arg LITELLM_TAG=${MAIN_TAG} \
	--build-arg LITELLM_BRANCH=${MAIN_CO_BRANCH} \
	--build-arg PATCH_VERSION=${DKR_IMAGE_TAG} \
	-t ${DKR_IMAGE_TAG} .

harbor-login:
	docker login harbor.cyverse.org

harbor:
	docker tag ${DKR_IMAGE_TAG} harbor.cyverse.org/wilma/litellm:${DKR_IMAGE_TAG}
	docker push harbor.cyverse.org/wilma/litellm:${DKR_IMAGE_TAG}

build-mod:
	docker build -f Dockerfile.mod -t ${DKR_IMAGE_TAG} .

run:
	docker run -it --rm \
	-p 4000:4000 \
	--env-file .env \
	--name docker.io/library/${DKR_IMAGE_TAG}

dkr-shell:
	docker compose exec -it litellm bash

delete-db:
	@sudo rm -rvf $(DIR)/postgresql/data; mkdir $(DIR)/postgresql/data; sudo chown -R 999:999 $(DIR)/postgresql/data