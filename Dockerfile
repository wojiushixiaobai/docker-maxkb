FROM node:18-bookworm AS stage-ui
ARG TARGETARCH

COPY ui /opt/maxkb/ui

WORKDIR /opt/maxkb/ui

RUN --mount=type=cache,target=/root/.npm \
    set -ex \
    && npm install \
    && npm run build \
    && rm -rf ./node_modules

FROM python:3.11-slim-bookworm AS stage-model
ARG TARGETARCH

WORKDIR /opt/maxkb/app

COPY installer/install_model.py install_model.py

RUN --mount=type=cache,target=/root/.cache \
    set -ex \
    && pip install pycrawlers \
    && pip install transformers \
    && python3 install_model.py

FROM python:3.11-slim-bookworm AS stage-build
ARG TARGETARCH

ARG DEPENDENCIES="                    \
        ca-certificates"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -ex \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache \
    && apt-get update \
    && apt-get install -y --no-install-recommends $DEPENDENCIES

COPY pyproject.toml /opt/maxkb/app/pyproject.toml

WORKDIR /opt/maxkb/app

RUN --mount=type=cache,target=/root/.cache \
    set -ex \
    && pip install poetry \
    && poetry config virtualenvs.create false \
    && python3 -m venv /opt/py3 \
    && . /opt/py3/bin/activate \
    && \
    if [ "$(uname -m)" = "x86_64" ]; then \
        sed -i 's/^torch.*/torch = {version = "^2.2.1+cpu", source = "pytorch"}/g' pyproject.toml; \
    fi \
    && poetry install

COPY . /opt/maxkb/app

RUN set -ex \
    && mkdir -p /opt/maxkb/model /opt/maxkb/conf \
    && rm -rf /opt/maxkb/app/ui

COPY --from=stage-ui /opt/maxkb/ui /opt/maxkb/app/ui

FROM python:3.11-slim-bookworm
ARG TARGETARCH

ARG DEPENDENCIES="                    \
        ca-certificates"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -ex \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache \
    && apt-get update \
    && apt-get install -y --no-install-recommends $DEPENDENCIES

ARG DOCKER_IMAGE_TAG=dev \
    BUILD_AT \
    GITHUB_COMMIT

ENV MAXKB_VERSION="${DOCKER_IMAGE_TAG} (build at ${BUILD_AT}, commit: ${GITHUB_COMMIT})" \
    MAXKB_CONFIG_TYPE=ENV \
    MAXKB_EMBEDDING_MODEL_NAME=/opt/maxkb/model/embedding/shibing624_text2vec-base-chinese \
    MAXKB_EMBEDDING_MODEL_PATH=/opt/maxkb/model/embedding \
    MAXKB_SANDBOX=true \
    LANG=en_US.UTF-8 \
    PATH=/opt/py3/bin:$PATH \
    PIP_TARGET=/opt/maxkb/app/sandbox/python-packages \
    PYTHONPATH=/opt/maxkb/app/sandbox/python-packages \
    PYTHONUNBUFFERED=1

COPY --from=stage-model /opt/maxkb/app/model /opt/maxkb/model
COPY --from=stage-build /opt /opt

RUN set -ex \
    && cp -r /opt/maxkb/model/base/hub /opt/maxkb/model/tokenizer \
    && mkdir -p /opt/maxkb/app/sandbox/python-packages \
    && find /opt/maxkb/app -mindepth 1 -not -name 'sandbox' -exec chmod 700 {} + \
    && useradd --no-create-home --home /opt/maxkb/app/sandbox --shell /bin/bash sandbox \
    && chown sandbox:sandbox /opt/maxkb/app/sandbox

WORKDIR /opt/maxkb/app

EXPOSE 8080

CMD ["python", "/opt/maxkb/app/main.py", "start"]