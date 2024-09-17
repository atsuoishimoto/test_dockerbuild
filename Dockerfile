ARG BASEIMAGE=python:3.12.4-slim-bookworm

FROM $BASEIMAGE AS build

RUN mkdir -p /opt/pythonenv/

WORKDIR /opt/pythonenv/

ENV PYTHONUNBUFFERED 5

# Setup build environment
RUN apt-get update
RUN apt-get install -y --no-install-recommends curl make gcc g++ libc-dev \
    pkg-config libmariadb-dev libyaml-dev libffi-dev

# Setup Poetry
ARG PIP_CACHE_DIR=/var/pip/cache
RUN --mount=type=cache,target=${PIP_CACHE_DIR} pip install poetry -v
RUN poetry config virtualenvs.in-project true

# Build packages
COPY pyproject.toml /opt/pythonenv/
COPY poetry.lock /opt/pythonenv/
RUN --mount=type=cache,target=${PIP_CACHE_DIR} poetry install --no-root --only main


#--------------------------------------------------------------
FROM $BASEIMAGE

ARG TARGETARCH

RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    libmariadb3 libyaml-0-2 libffi8 && \
    apt-get purge -y --auto-remove \
    -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* /var/tmp/* /root/.cache/*

RUN mkdir -p /usr/src/app
RUN mkdir -p /opt/pythonenv/

WORKDIR /usr/src/app

COPY src /usr/src/app

COPY --from=build --chown=appuser /opt/pythonenv/.venv /opt/pythonenv/.venv

ENV PATH="/opt/pythonenv/.venv/bin:${PATH}"

RUN python -m manage collectstatic --noinput --settings=poetrydjango.settings

CMD ["python", "-m", "manage", "runserver"]
