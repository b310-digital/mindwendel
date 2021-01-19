FROM elixir:1.11-alpine

RUN apk add --update-cache \
    postgresql-client \
    nodejs nodejs-npm

WORKDIR /app

COPY . .
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN npm --prefix assets install
RUN mix compile

RUN ["chmod", "+x", "./entrypoint.sh"]
ENTRYPOINT ["sh", "./entrypoint.sh"]