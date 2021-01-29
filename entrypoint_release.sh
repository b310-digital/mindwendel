#!/bin/bash

while ! pg_isready -q -h $DATABASE_HOST -p $DATABASE_PORT -U $DATABASE_USER
do
  echo "Waiting for database."
  sleep 2
done

exec ./bin/mindwendel eval "Mindwendel.Release.migrate"
exec ./bin/mindwendel start