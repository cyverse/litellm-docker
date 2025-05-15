ARG LITELLM_RUNTIME_IMAGE=ghcr.io/berriai/litellm:main-v1.67.4-stable

# 1. start FROM your published/built image
FROM $LITELLM_RUNTIME_IMAGE AS runtime2

## Note: this needs to match the image we're working with
ARG LITELLM_TAG=v1.67.4-stable
ENV LITELLM_TAG=$LITELLM_TAG
ARG LITELLM_BRANCH=main-v1.67.4-stable
ENV LITELLM_BRANCH=$LITELLM_BRANCH

ARG PATCH_VERSION=v1.67.4-stable-20250515
ENV PATCH_VERSION=$PATCH_VERSION

# 2. (optional) switch to root if you need to install extra packages
USER root
RUN apk add --no-cache git vim

# 3. overwrite /app with your local source
# WORKDIR /app
# COPY . /app
COPY ${PATCH_VERSION}-litellm.patch .
RUN git apply ${PATCH_VERSION}-litellm.patch

##########################################################
### NOTE: this part is sketchy to me / might fail
RUN pip install --upgrade pip build \
    && python -m build

# Build Admin UI
RUN chmod +x docker/build_admin_ui.sh && ./docker/build_admin_ui.sh

# Build the package
RUN rm -rf dist/* && python -m build

# There should be only one wheel file now, assume the build only creates one
RUN ls -1 dist/*.whl | head -1

# Install the package
RUN pip install dist/*.whl

# install dependencies as wheels
RUN pip wheel --no-cache-dir --wheel-dir=/wheels/ -r requirements.txt

# ensure pyjwt is used, not jwt
RUN pip uninstall jwt -y
RUN pip uninstall PyJWT -y
RUN pip install PyJWT==2.9.0 --no-cache-dir

# Build Admin UI
RUN chmod +x docker/build_admin_ui.sh && ./docker/build_admin_ui.sh

# Runtime stage same as build stage?!?
RUN ls -la /app

# Install the built wheel using pip; again using a wildcard if it's the only file
# RUN pip install *.whl /wheels/* --no-index --find-links=/wheels/ && rm -f *.whl && rm -rf /wheels
RUN pip install --no-index \
    --find-links=/wheels/ \
    /app/*.whl \
    /wheels/*.whl && \
    rm -f /app/*.whl && \
    rm -rf /wheels

## End of sketchy part
##########################################################

# 4. if you need to rebuild assets, wheels, etc, kick that off here
#    for example, rebuild prisma client if your schema changed:
# Generate prisma client
RUN prisma generate
RUN chmod +x docker/entrypoint.sh
RUN chmod +x docker/prod_entrypoint.sh

# 5. set the command to what you use in dev
# ENTRYPOINT ["docker/prod_entrypoint.sh"]
# CMD ["--port", "4000"]

# entrypoint to run shell
ENTRYPOINT ["/bin/sh"]