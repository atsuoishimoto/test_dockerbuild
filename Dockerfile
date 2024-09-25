ARG BASEIMAGE=python:3.12.4-slim-bookworm

FROM $BASEIMAGE AS build

WORKDIR /opt/pythonenv/

# Setup build environment
RUN apt-get update
RUN apt-get install -y --no-install-recommends curl make gcc g++ libc-dev \
                    pkg-config libmariadb-dev libyaml-dev libffi-dev

# Setup Poetry
ENV PIP_CACHE_DIR=/var/pip/cache
ENV POETRY_CACHE_DIR=/var/poetry/cache
ENV POETRY_HOME=/opt/poetry

RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    curl -sSL https://install.python-poetry.org | python3 -

ENV PATH="${POETRY_HOME}/bin:${PATH}"
RUN poetry config virtualenvs.in-project true

# Build packages
COPY pyproject.toml /opt/pythonenv/
COPY poetry.lock /opt/pythonenv/
RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    --mount=type=cache,target=${POETRY_CACHE_DIR} \
    poetry install --no-root --only main


#--------------------------------------------------------------
FROM $BASEIMAGE AS runtime_base

ARG TARGETARCH

RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libmariadb3 libyaml-0-2 libffi8 && \
    apt-get purge -y --auto-remove \
        -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* /var/tmp/* /root/.cache/*

RUN mkdir /log
RUN mkdir -p /usr/src/app
RUN mkdir -p /opt/pythonenv/

RUN groupadd -g 999 appuser && \
    useradd -r -u 999 -g appuser appuser && \
    chown -R appuser:appuser /usr/src/app /log


WORKDIR /opt/utils
RUN cat <<EOF > wait_mysql.py
from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("select 999")
    print(cursor.fetchone())
EOF

RUN cat <<EOF > wait_mysql.sh
#!/bin/sh
while ! python -m manage shell < /opt/utils/wait_mysql.py > /dev/null 2>&1; do
  echo waiting db
  sleep 1
done
EOF
RUN chmod +x wait_mysql.sh


WORKDIR /usr/src/app
RUN chown appuser.appuser .

COPY --from=build --chown=appuser /opt/pythonenv/.venv /opt/pythonenv/.venv


#--------------------------------------------------------------
FROM runtime_base AS dev

# Setup Poetry
ENV PIP_CACHE_DIR=/var/pip/cache
ENV POETRY_CACHE_DIR=/var/poetry/cache
ENV POETRY_HOME=/opt/poetry
ENV PATH="${POETRY_HOME}/bin:${PATH}"

COPY --from=build --chown=appuser ${POETRY_HOME} ${POETRY_HOME}

WORKDIR /opt/pythonenv
COPY pyproject.toml /opt/pythonenv/
COPY poetry.lock /opt/pythonenv/
RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    --mount=type=cache,target=${POETRY_CACHE_DIR} \
    ${POETRY_HOME}/bin/poetry install --no-root

ENV PATH="/opt/pythonenv/.venv/bin:${PATH}"
ENV PYTHONPATH=/usr/src/app/src

COPY --chown=appuser . /usr/src/app
WORKDIR /usr/src/app
#CMD /opt/utils/wait_mysql.sh && /bin/bash

CMD /opt/utils/wait_mysql.sh && /bin/bash

#--------------------------------------------------------------
FROM runtime_base AS runtime

USER appuser

ENV PYTHONUNBUFFERED=1
ENV PATH="/opt/pythonenv/.venv/bin:${PATH}"
ENV PYTHONPATH=/usr/src/app/src

COPY --chown=appuser . /usr/src/app
RUN python -m manage collectstatic --noinput --settings=poetrydjango.settings

CMD ["python", "-m", "manage", "runserver", "0.0.0.0:8000"]
