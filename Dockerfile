# Base image for building
ARG LITELLM_BUILD_IMAGE=cgr.dev/chainguard/python:latest-dev

# Runtime image
ARG LITELLM_RUNTIME_IMAGE=cgr.dev/chainguard/python:latest-dev

# Builder source stage
FROM $LITELLM_BUILD_IMAGE AS builder

ARG LITELLM_TAG=v1.67.4-stable
ENV LITELLM_TAG=$LITELLM_TAG
ARG LITELLM_BRANCH=main-v1.67.4-stable
ENV LITELLM_BRANCH=$LITELLM_BRANCH

ARG PATCH_VERSION=v1.67.4-stable-20250516
ENV PATCH_VERSION=$PATCH_VERSION

# Set the working directory to /app
WORKDIR /app

USER root

# Install build dependencies
RUN apk add --no-cache gcc python3-dev openssl openssl-dev

# Instead of using current directory, we will clone the repo using git tag release
RUN apk add --no-cache git build-base \
    && git config --global --add safe.directory /app \
    && git clone --depth=1 --branch $LITELLM_TAG https://github.com/BerriAI/litellm.git . \
    && git checkout -b $LITELLM_BRANCH

# Apply the cyverse patches
COPY ${PATCH_VERSION}-litellm.patch .
RUN git apply ${PATCH_VERSION}-litellm.patch --allow-empty

# rebuild the package
RUN pip install --upgrade pip build \
    && python -m build

# Copy the current directory contents into the container at /app
# COPY . .

# Build Admin UI
RUN chmod +x docker/build_admin_ui.sh && ./docker/build_admin_ui.sh

# Build the package
RUN rm -rf dist/* && python -m build

# There should be only one wheel file now, assume the build only creates one
RUN ls -1 dist/*.whl | head -1

# Install the package
RUN pip install --force-reinstall dist/*.whl

# install dependencies as wheels
RUN pip wheel --no-cache-dir --wheel-dir=/wheels/ -r requirements.txt

# ensure pyjwt is used, not jwt
RUN pip uninstall jwt -y
RUN pip uninstall PyJWT -y
RUN pip install PyJWT==2.9.0 --no-cache-dir

# Build Admin UI
RUN chmod +x docker/build_admin_ui.sh && ./docker/build_admin_ui.sh

# Runtime stage
FROM $LITELLM_RUNTIME_IMAGE AS runtime

ARG LITELLM_TAG=v1.67.4-stable
ENV LITELLM_TAG=$LITELLM_TAG
ARG LITELLM_BRANCH=main-v1.67.4-stable
ENV LITELLM_BRANCH=$LITELLM_BRANCH

ARG PATCH_VERSION=v1.67.4-stable-20250516
ENV PATCH_VERSION=$PATCH_VERSION

# Ensure runtime stage runs as root
USER root

# Install runtime dependencies
RUN apk add --no-cache openssl

WORKDIR /app
# Copy the current directory contents into the container at /app
# COPY . .

# Install build dependencies
RUN apk add --no-cache gcc python3-dev openssl openssl-dev

# Instead of using current directory, we will clone the repo using git tag release (replaces COPY . .)
RUN apk add --no-cache git build-base \
    && git config --global --add safe.directory /app \
    && git clone --depth=1 --branch $LITELLM_TAG https://github.com/BerriAI/litellm.git . \
    && git checkout -b $LITELLM_BRANCH

# Apply the cyverse patches
COPY ${PATCH_VERSION}-litellm.patch .
RUN git apply ${PATCH_VERSION}-litellm.patch --allow-empty

COPY --from=builder /app/docker/entrypoint.sh docker/.
COPY --from=builder /app/docker/prod_entrypoint.sh docker/.
RUN ls -la /app

# Copy the built wheel from the builder stage to the runtime stage; assumes only one wheel file is present
COPY --from=builder /app/dist/*.whl .
COPY --from=builder /wheels/ /wheels/

# Install the built wheel using pip; again using a wildcard if it's the only file
RUN pip install *.whl /wheels/* --no-index --find-links=/wheels/ && rm -f *.whl && rm -rf /wheels

# Generate prisma client
RUN prisma generate
RUN chmod +x docker/entrypoint.sh
RUN chmod +x docker/prod_entrypoint.sh

EXPOSE 4000/tcp

ENTRYPOINT ["docker/prod_entrypoint.sh"]

# Append "--detailed_debug" to the end of CMD to view detailed debug logs
CMD ["--port", "4000"]

# entrypoint to run shell
# ENTRYPOINT ["/bin/sh"]