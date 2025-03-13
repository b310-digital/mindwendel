# Installing and Running mindwendel

We have prepared different installation configurations for you. A postgres database server is the only external dependency needed by mindwendel in order to store all application data.

Below, we provide detailed instructions on how to install and run mindwendel:

- [Running on Docker Compose](#running-on-docker-compose)
- [Running behind a reverse proxy](#running-behind-a-reverse-proxy)
- [Running on Gigalixir](#running-on-gigalixir)

## Running on Docker Compose

When you use [docker compose](https://docs.docker.com/compose/), you will be using one or several `docker-compose.yml` files.

- Add the following snippets to one of your `docker-compose.yml` file or simply use our `docker-compose-prod.yml` file and add your own passwords and configs:

  ```yml
  services:
    # You might already have other docker services listed in your docker-compose file
    # ...

    # Add the following mindwendel service
    mindwendel:
      image: ghcr.io/b310-digital/mindwendel:latest
      environment:
        # Add the address of the database host, so that mindwendel can find the database, e.g. an ip address or a reference to another service in the docker-compose file
        DATABASE_HOST: db

        # Add the port of the database host (default is 5432)
        DATABASE_PORT: 5432

        # Add the database name that mindwendel should use, e.g. in this case we created and named the database `mindwendel_prod`
        DATABASE_NAME: "mindwendel_prod"

        # Add the credentials for the database user that mindwendel should use to access the database
        # NOTE: The database user should have read and write permissions
        DATABASE_USER: "mindwendel_db_user"
        DATABASE_USER_PASSWORD:

        # Secure connection to database, especially in a remote db setup
        DATABASE_SSL: false

        # Add the url host that points to this mindwendel installation. This is used by mindwendel to generate urls with the right host throughout the app.
        URL_HOST: "your_domain_to_mindwendel"
        URL_PORT: 80

        # for non local setups, ssl should be set to true!
        DATABASE_SSL: "false"
        MW_DEFAULT_LOCALE: en

        # MW Features
        MW_FEATURE_BRAINSTORMING_REMOVAL_AFTER_DAYS: 30
        MW_FEATURE_BRAINSTORMING_TEASER: true
        MW_FEATURE_IDEA_FILE_UPLOAD: true

        # Variables for your s3 file storage
        OBJECT_STORAGE_BUCKET: mindwendel
        OBJECT_STORAGE_SCHEME: "https://"
        OBJECT_STORAGE_HOST: minio
        OBJECT_STORAGE_PORT: 9000
        OBJECT_STORAGE_REGION: local
        OBJECT_STORAGE_USER:
        OBJECT_STORAGE_PASSWORD:
        # To generate a vault encryption key, you can use either:
        # openssl rand -base64 32
        # OR
        # iex
        # iex> 32 |> :crypto.strong_rand_bytes() |> Base.encode64()
        VAULT_ENCRYPTION_KEY_BASE64:

        # Add a secret key base for mindwendel for encrypting the use session
        # NOTE: There are multiple commands you can use to generate a secret key base. Pick one command you like, e.g.:
        # `date +%s | sha256sum | base64 | head -c 64 ; echo`
        # See https://www.howtogeek.com/howto/30184/10-ways-to-generate-a-random-password-from-the-command-line/
        SECRET_KEY_BASE: "generate_your_own_secret_key_base_and_save_it"

      # Add the url host that points to this mindwendel installation.
      # This is used by mindwendel to generate urls with the right host throughout the app.
      URL_HOST: localhost
      # 80 for http
      URL_PORT: 443
      # http or https
      URL_SCHEME: https

      # This env var defines to what port the phoeinx (cowboy) server should listen to.
      # Given that we are target port is 4000 (see below) it likely that the phoenix server should also listen to this port 4000.
      MW_ENDPOINT_HTTP_PORT: 4000
      ports:
        - "80:4000"
      depends_on:
        - db

    # If you do not have another postgres database service in this docker-compose, you can add this postgres service.
    # Note: Please use other credentials when using this in production.
    db:
      image: postgres:latest
      # Pass config parameters to the postgres server.
      # Find more information below when you need to generate the ssl-relevant file your self
      # command: -c ssl=on -c ssl_cert_file=/var/lib/postgresql/server.crt -c ssl_key_file=/var/lib/postgresql/server.key
      environment:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD:
        PGDATA: /var/lib/postgresql/data/pgdata
      restart: always
      ports:
        - "5432:5432"
      # This is important for a production setup in order ot presist the mindwendel database even the docker container is stopped and removed
      volumes:
        - pgdata:/var/lib/postgresql/data

    # minio acts as a backend for file storage
    minio:
    image: minio/minio
    container_name: minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minio_user
      MINIO_ROOT_PASSWORD:
    volumes:
      - ~/minio/data:/data
    command: server /data --console-address ":9001"

  volumes:
      # To setup an ssl-enabled postgres server locally, you need to generate a self-signed ssl certificate.
      # See README.md for more information.
      # Mount the ssl_cert_file and ssl_key_file into the docker container.
      # - ./ca/server.crt:/var/lib/postgresql/server.crt
      # - ./ca/server.key:/var/lib/postgresql/server.key
    pgdata:
  ```

- To run mindwendel via Docker Compose, just type

  ```sh
  docker compose up -d
  ```

- To create the production database (after having created the containers via up):

  First, start the container:

  ```sh
  docker start mindwendel_db_1
  ```

  Then eiher:

  ```sh
  docker exec -it mindwendel_db_1 createuser -rPed mindwendel_db_user --username=postgres
  docker exec -it mindwendel_db_1 createdb mindwendel_prod --username=mindwendel_db_user
  ```

  Or login to the container and do it from there:

  ```sh
  docker exec -it mindwendel_db_1 sh
  su -- postgres
  psql
  postgres=# CREATE USER mindwendel_db_user WITH PASSWORD 'mindwendel_db_user_password';
  postgres=# CREATE DATABASE mindwendel_prod;
  postgres=# GRANT ALL PRIVILEGES ON DATABASE mindwendel_prod TO mindwendel_db_user;
  \q
  exit
  ```

  ...or use any other database client of your choice to create the database!

  After that, adjust the db password in the docker compose file accordingly.

  Note: Adjust the env vars in `docker-compose.yml` according to your preferences.

## Running behind a reverse proxy

Mindwendel can be configured to run behind a reverse proxy with SSL termination. Here's how to set it up:

### Prerequisites

- A reverse proxy server (e.g., Nginx)
- A valid SSL certificate

### SSL Certificate Requirements

Your reverse proxy needs to handle SSL termination with a valid certificate. You can obtain one through:
- Let's Encrypt (recommended)
- Your own Certificate Authority (CA)
- A commercial SSL provider

### Nginx Configuration Example

Here's a basic Nginx configuration template. Adjust the values according to your setup:

```
events {
  worker_connections 1024;
}

http {
	server {
	  listen 80;
	  listen [::]:80;
	
	  server_name mindwendel.domain.tld;
	  return 301 https://$host$request_uri;
	}
	
	server {
	
	  listen 443 ssl;
	  listen [::]:443 ssl;
	
	  server_name mindwendel.domain.tld;
	
	  ssl_certificate /etc/letsencrypt/live/domain.tld/fullchain.pem;
	  ssl_certificate_key /etc/letsencrypt/live/domain.tld/privkey.pem;
	
	  location / {
	      proxy_pass http://mindwendel:4000/;
	      proxy_http_version 1.1;
	      proxy_set_header Host $http_host;
	      proxy_set_header X-Real-IP $remote_addr;
	      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	      proxy_set_header X-Forwarded-Proto $scheme;
	      proxy_set_header Upgrade $http_upgrade;
	      proxy_set_header Connection "Upgrade";
	  }
	}
}
```

## Running on Gigalixir

Gigalixir.com is a plattform as a service that fully supports Elixir and Phoenix.

Follow the steps as described in [this guide](https://hexdocs.pm/phoenix/gigalixir.html#content).

Note: Because of the releases.exs, Gigalixir automatically deploys the app as an elixir release. This is why `gigalixir run mix ecto.migrate` will not work. However, the Gigalixir team provides another utility command that helps with the migration `gigalixir ps:migrate`, see https://gigalixir.readthedocs.io/en/latest/database.html#how-to-run-migrations .
