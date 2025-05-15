# make file to build Dockerfile image

# get Makefile's directory
DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# exit Makefile with error if DIR is not set, and does not end with litellm-cyverse
ifeq ($(DIR),)
$(error DIR is not set)
endif

ifneq ($(findstring litellm-docker,$(DIR)),litellm-docker)
$(error DIR must contain "litellm-docker" (got "$(DIR)") )
endif

IMAGE_VERSION := v1.67.4-stable-20250515

.PHONY: build run

# build litellm container with patch
build:
	docker build -t ${IMAGE_VERSION} .

harbor-login:
	docker login harbor.cyverse.org

harbor:
	docker tag ${IMAGE_VERSION} harbor.cyverse.org/wilma/litellm:${IMAGE_VERSION}
	docker push harbor.cyverse.org/wilma/litellm:${IMAGE_VERSION}

build-mod:
	docker build -f Dockerfile.mod -t ${IMAGE_VERSION} .

run:
	docker run -it --rm \
	-p 4000:4000 \
	--env-file .env \
	--name
	docker.io/library/${IMAGE_VERSION}

dkr-shell:
	docker compose exec -it litellm bash

delete-db:
	@sudo rm -rvf $(DIR)/postgresql/data; mkdir $(DIR)/postgresql/data; sudo chown -R 999:999 $(DIR)/postgresql/data