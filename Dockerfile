ARG BASEIMAGE=python:3.12.4-slim-bookworm

FROM $BASEIMAGE AS build

RUN mkdir -p /opt/pythonenv/

WORKDIR /opt/pythonenv/

ENV PYTHONUNBUFFERED 1

# Setup build environment
RUN apt-get update
RUN apt-get install -y --no-install-recommends curl make gcc g++ libc-dev \
                    pkg-config libmariadb-dev libyaml-dev libffi-dev
RUN curl -sSL https://install.python-poetry.org | POETRY_HOME=/opt/poetry python -

# Setup Poetry
RUN ln -s /opt/poetry/bin/poetry /usr/local/bin/poetry
RUN poetry config virtualenvs.in-project true

# Build packages
COPY pyproject.toml /opt/pythonenv/
COPY poetry.lock /opt/pythonenv/
RUN poetry install --no-root --only main


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
