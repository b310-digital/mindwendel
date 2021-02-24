
ARG ALPINE_VERSION=3.13

FROM elixir:1.11-alpine as elixir_alpine

RUN apk add --update-cache postgresql-client nodejs npm

RUN mix do local.hex --force, local.rebar --force

WORKDIR /app

COPY . .

FROM elixir_alpine as development

RUN mix do deps.get, compile
RUN npm --prefix assets install

RUN ["chmod", "+x", "./entrypoint.sh"]
ENTRYPOINT ["sh", "./entrypoint.sh"]


# Building a release version
# https://hexdocs.pm/phoenix/releases.html
FROM elixir_alpine AS build

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
RUN mix do deps.get, deps.compile

# Build assets
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error
RUN npm run --prefix ./assets deploy
RUN mix phx.digest

# compile and build release
RUN mix do compile, release

# prepare release image
FROM alpine:${ALPINE_VERSION} AS app

# Labels Standard
LABEL org.label-schema.schema-version="1.0"
# LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.name="mindwendel/mindwendel"
LABEL org.label-schema.description="mindwendel application"
LABEL org.label-schema.vcs-url="https://github.com/mindwendel/mindwendel"
# LABEL org.label-schema.vcs-ref=$VCS_REF
LABEL org.label-schema.vendor="WSO2"
# LABEL org.label-schema.version=$BUILD_VERSION
LABEL org.label-schema.docker.cmd="docker run -d --name mindwendel -p 127.0.0.1:80:4000 -e DATABASE_HOST=\"...\" -e DATABASE_PORT=\"5432\" -e DATABASE_NAME=\"mindwendel_prod\" -e DATABASE_USER=\"mindwendel_db_user\" -e DATABASE_USER_PASSWORD=\"mindwendel_db_user_password\" -e SECRET_KEY_BASE=\"generate_your_own_secret_key_base_and_save_it\" -e URL_HOST=\"your_domain_to_mindwendel\" ghcr.io/mindwendel/mindwendel"
LABEL org.opencontainers.image.source="https://github.com/mindwendel/mindwendel"
LABEL maintainer="gerardo.navarro.suarez@gmail.com"

RUN apk add --no-cache openssl ncurses-libs postgresql-client

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY entrypoint.release.sh /app/entrypoint.release.sh
COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/mindwendel ./

ENV HOME=/app

ENTRYPOINT ["sh", "./entrypoint.release.sh"]