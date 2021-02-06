#!/bin/bash

while ! pg_isready -q -h $DATABASE_HOST -p $DATABASE_PORT -U $DATABASE_USER
do
  echo "Waiting for database."
  sleep 2
done

if [[ -z `psql -Atq -h $DATABASE_HOST -p $DATABASE_PORT -U $DATABASE_USER -W $DATABASE_USER_PASSWORD -c "\\list $DATABASE_NAME"` ]]; then
  mix ecto.create
  mix ecto.migrate
  mix run priv/repo/seeds.exs
  echo "Database $DATABASE_NAME created."
fi

exec mix phx.server