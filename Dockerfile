
ARG ALPINE_VERSION=3.13

FROM elixir:1.11-alpine as elixir_alpine

RUN apk add --update-cache postgresql-client nodejs npm

RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /app

COPY . .

FROM elixir_alpine as development

RUN mix deps.get
RUN npm --prefix assets install
RUN mix compile

RUN ["chmod", "+x", "./entrypoint.sh"]
ENTRYPOINT ["sh", "./entrypoint.sh"]


# Building a release version
# https://hexdocs.pm/phoenix/releases.html
FROM elixir_alpine AS build

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
RUN mix deps.compile

# Build assets
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error
RUN npm run --prefix ./assets deploy
RUN mix phx.digest

# compile and build release
RUN mix do compile, release

# prepare release image
FROM alpine:${ALPINE_VERSION} AS app
RUN apk add --no-cache openssl ncurses-libs postgresql-client

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY entrypoint.release.sh /app/entrypoint.release.sh
COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/mindwendel ./

ENV HOME=/app

ENTRYPOINT ["sh", "./entrypoint.release.sh"]