# Installing and Running mindwendel

We have prepared different installation configurations for you. A postgres database server is the only external dependency needed by mindwendel in order to store all application data.

Below, we provide detailed instructions on how to install and run mindwendel in a variety of common configurations:

- [Running on Docker-Compose](#running-on-docker-compose) (RECOMMENDED)
- [Running on Docker](#running-on-docker)

## Running on Docker-Compose

When you use [docker-compose](https://docs.docker.com/compose/), you will be using one or several `docker-compose.yml` files.

- Add the following snippets to one of your `docker-compose.yml` file

  ```yml
  services:
    # You might already have other docker services listed in your docker-compose file
    # ...

    # Add the following mindwendel service
    mindwendel:
      image: ghcr.io/mindwendel/mindwendel:latest
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
        DATABASE_USER_PASSWORD: "mindwendel_db_user_password"

        # Add the url host that points to this mindwendel installation. This is used by mindwendel to generate urls with the right host throughout the app.
        URL_HOST: "your_domain_to_mindwendel"

        # Add a secret key base for mindwendel for encrypting the use session
        # NOTE: There are multiple commands you can use to generate a secret key base. Pick one command you like, e.g. `date +%s | sha256sum | base64 | head -c 64 ; echo`
        # See https://www.howtogeek.com/howto/30184/10-ways-to-generate-a-random-password-from-the-command-line/
        SECRET_KEY_BASE: "generate_your_own_secret_key_base_and_save_it"
      ports:
        - "80:4000"
      depends_on:
        - db

    # If you do not have another postgres database service in this docker-compose, you can add this postgres service.
    # Note: Please use other credentials when using this in production.
    db:
      image: postgres:latest
      environment:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
        PGDATA: /var/lib/postgresql/data/pgdata
      restart: always
      ports:
        - "5432:5432"
      # This is important for a production setup in order ot presist the mindwendel database even the docker container is stopped and removed
      volumes:
        - pgdata:/var/lib/postgresql/data
  volumes:
    pgdata:
  ```

- To run mindwendel via Docker-Compose, just type
  ```sh
  docker-compose up
  ```

Note: Adjust the env vars in `docker-copmose.yml`.

## Running on Docker

If you are using Docker containers and prefer to manage your mindwendel installation that way then we’ve got you covered. This guide discusses how to use the mindwendel docker image to launch a container running mindwendel.

- Run mindwendel via [Docker](https://docs.docker.com/engine/reference/run/) (without postgres database)
  ```sh
  docker run -d --name mindwendel \
    -p 127.0.0.1:80:4000 \
    -e DATABASE_HOST="..." \
    -e DATABASE_PORT="5432" \
    -e DATABASE_NAME="mindwendel_prod" \
    -e DATABASE_USER="mindwendel_db_user" \
    -e DATABASE_USER_PASSWORD="mindwendel_db_user_password" \
    -e SECRET_KEY_BASE="generate_your_own_secret_key_base_and_save_it" \
    -e URL_HOST="your_domain_to_mindwendel" \
    ghcr.io/mindwendel/mindwendel
  ```

NOTE: mindwendel requires a postgres database. You can use our docker-compose file to also install the postgres, see [above](#running-on-docker-compose).
