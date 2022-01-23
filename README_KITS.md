# kits version of mindwendel

This project includes a few CI changes to the mindwendel software.

## Installation

- Build the image for the docker container

  ```bash
  docker-compose -f docker-compose-kits.yml build
  ```

- Start up the docker containers

  ```bash
  docker-compose -f docker-compose-kits.yml up --build --force-recreate
  ```

Important: Make sure to exchange passwords with proper ones!

See main README for project specifics.

## Maintenance

### Dump postgres database from docker service

- Create directory to store future backups

  ```bash
  mkdir -p database-backup
  ```

- Dump the current state of the database into a file on the docker host; please replace the placeholders `{{database_user}}` and `{{database_name}}`

  ```bash
  docker-compose -f docker-compose-kits.yml exec -T db pg_dump -c -U {{database_user}} {{database_name}} > ./database-backup/database-backup-{{database_name}}-`date +%d-%m-%Y-%H-%M-%S`.dump
  ```

### Restore Postgres backup

- Restore the state of the database; please replace the placeholders `{{database_user}}` and `{{database_name}}`

  ```bash
  docker-compose -f docker-compose-kits.yml exec -T db psql -U {{database_user}} {{database_name}} < ./path-to-postgres-sql-dump.dump
  ```
