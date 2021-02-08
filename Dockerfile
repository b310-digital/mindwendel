FROM elixir:1.11-alpine as development

RUN apk add --update-cache \
    postgresql-client \
    nodejs npm

WORKDIR /app

COPY . .
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN npm --prefix assets install
RUN mix compile

RUN ["chmod", "+x", "./entrypoint.sh"]
ENTRYPOINT ["sh", "./entrypoint.sh"]

# https://hexdocs.pm/phoenix/releases.html
FROM development AS build

ARG secret
ARG MINDWENDEL_RELEASE
ENV SECRET_KEY_BASE=$secret

# install build dependencies
RUN apk add --no-cache build-base npm git python3 curl tar
RUN apk add --no-cache --upgrade grep
# get files from release and unpack to /app folder
RUN if [ -z ${MINDWENDEL_RELEASE+x} ]; then \
 	MINDWENDEL_RELEASE=$(curl --silent "https://api.github.com/repos/mindwendel/mindwendel/releases" | grep -oP -m 1 '"tag_name": "\K(.*)(?=")'); \
 fi && mkdir -p /app && \
 curl -o /tmp/mindwendel.tar.gz -L "https://github.com/Mindwendel/Mindwendel/archive/${MINDWENDEL_RELEASE}.tar.gz" && \
 tar xf /tmp/mindwendel.tar.gz -C /app --strip-components=1 && rm -Rf /tmp/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
RUN mix do deps.get, deps.compile

# build assets
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

RUN npm run --prefix ./assets deploy
RUN mix phx.digest

# compile and build release
RUN mix do compile, release

# prepare release image
FROM alpine:3.13 AS app
RUN apk add --no-cache openssl ncurses-libs postgresql-client

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY entrypoint.release.sh /app/entrypoint.release.sh
COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/mindwendel ./

ENV HOME=/app

ENTRYPOINT ["sh", "./entrypoint.release.sh"]