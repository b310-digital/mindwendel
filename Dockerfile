
ARG ALPINE_VERSION=3.13

FROM elixir:1.11-alpine as elixir_alpine

ENV APP_PATH=/app

RUN apk add \
    --update-cache \
    nodejs \
    npm

RUN mix do local.hex --force, local.rebar --force

WORKDIR $APP_PATH

FROM elixir_alpine as development

RUN apk add \
    # The package `inotify-tools` is needed for instant live-reload of the the phoenix server
    inotify-tools \
    postgresql-client

# Install mix dependencies
COPY mix.exs mix.lock $APP_PATH/
RUN mix do deps.get

COPY assets/package.json assets/package-lock.json $APP_PATH/assets/
RUN npm install --prefix assets

COPY . .

# Building a release version
# https://hexdocs.pm/phoenix/releases.html
FROM elixir_alpine AS production_build

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock $APP_PATH/
RUN mix do deps.get, deps.compile

# Build assets
COPY assets $APP_PATH/assets/
RUN set -eux; \
    npm \
      --loglevel=error \
      --no-audit \
      --prefix assets \
      --progress=false \
      ci ; \
    npm \
      --prefix assets \
      run \
      deploy

# Compile and build release
COPY . .
RUN mix do phx.digest, compile, release

# Prepare release image
FROM alpine:${ALPINE_VERSION} AS production

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

ENV APP_PATH=/app

RUN apk add --no-cache \
      libgcc \
      libstdc++ \
      ncurses-libs \
      openssl \
      postgresql-client

WORKDIR $APP_PATH

RUN chown nobody:nobody $APP_PATH/

USER nobody:nobody

COPY --from=production_build --chown=nobody:nobody $APP_PATH/_build/prod/rel/mindwendel ./

ENV HOME=$APP_PATH

COPY --chown=nobody:nobody entrypoint.release.sh $APP_PATH/entrypoint.release.sh
ENTRYPOINT ["sh", "entrypoint.release.sh"]

EXPOSE 80