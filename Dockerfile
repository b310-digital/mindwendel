# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20210902-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.13.1-erlang-24.2-debian-bullseye-20210902-slim
#
ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.1.2
ARG DEBIAN_VERSION=bookworm-20241111-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# This is our base image for development as well as building the production image:
FROM ${BUILDER_IMAGE} AS base

# Install node
ENV NODE_MAJOR=22

RUN apt-get -y update

RUN apt-get install -y ca-certificates curl gnupg
RUN mkdir -p /etc/apt/keyrings  
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# install build dependencies
RUN apt-get update && apt-get install -y nodejs \
  build-essential \
  inotify-tools \ 
  postgresql-client \
  ca-certificates \
  git \
  cmake && \
  apt-get clean && \ 
  rm -f /var/lib/apt/lists/*_*

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

FROM base AS development
RUN groupadd --gid 1000 elixir \
  && useradd --uid 1000 --gid elixir --shell /bin/bash --create-home elixir

RUN mkdir -p /usr/local/share/npm-global && \
  chown -R elixir:elixir /usr/local/share

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

WORKDIR /home/elixir/app
USER elixir

FROM base AS production_builder
# prepare build dir
WORKDIR /app

# set build ENV
ENV MIX_ENV="prod"
ENV NODE_ENV="production"
# This is required for arm64 builds, see https://elixirforum.com/t/mix-deps-get-memory-explosion-when-doing-cross-platform-docker-build/57157
ENV ERL_FLAGS="+JPperf true"

# Setting this env var will avoid warnings from the production config
# We could leave it as it as no effect on the build output
ENV SECRET_KEY_BASE="dummy_secret_key_base_to_avoid_warning_from_production_config"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# Install npm packages:
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm install --prefix assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS production

RUN apt-get update -y && apt-get install -y ca-certificates libstdc++6 postgresql-client openssl libncurses5 locales \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=production_builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/mindwendel ./

USER nobody

CMD ["/app/bin/server"]