FROM elixir:1.11-alpine as development

RUN apk add --update-cache \
    postgresql-client \
    nodejs \
    npm

WORKDIR /app

COPY . .

RUN mix do local.hex --force, local.rebar --force

RUN mix do deps.get, compile

RUN npm --prefix assets install

RUN ["chmod", "+x", "./entrypoint.sh"]
ENTRYPOINT ["sh", "./entrypoint.sh"]

# https://hexdocs.pm/phoenix/releases.html
FROM development AS build

ENV MIX_ENV=prod

RUN npm --prefix assets ci --progress=false --no-audit --loglevel=error && \
    npm --prefix assets run deploy

# install mix dependencies
RUN mix do deps.get, deps.compile