# mindwendel

![Workflow Status Badge](https://github.com/b310-digital/mindwendel/actions/workflows/on_push_branch__execute_ci_cd.yml/badge.svg)

Create a challenge. Ready? Brainstorm. mindwendel helps you to easily brainstorm and upvote ideas and thoughts within your team. Built from scratch with [Phoenix](https://www.phoenixframework.org).

- [mindwendel](#mindwendel)
  - [Features](#features)
  - [Use-cases](#use-cases)
  - [Getting Started](#getting-started)
  - [Contributing](#contributing)
    - [Workflow](#workflow)
    - [Development](#development)
    - [Testing](#testing)
    - [Production](#production)
      - [Note](#note)
    - [Build release and production docker image](#build-release-and-production-docker-image)
    - [Formatting](#formatting)
  - [Environment Variables](#environment-variables)
    - [Localization](#localization)
  - [Testimonials](#testimonials)
  - [Acknowledgements](#acknowledgements)

## Features

- 5 minute setup (It is not a joke)
- Anonymously invite people to your brainstormings - no registration needed. Usernames are optional!
- Easily create and upvote ideas, with live updates from your mindwendel members
- Cluster or filter your ideas with custom labels
- Preview of links to ease URL sharing
- Add automatically encrypted file attachments which are uploaded to an S3 compatible storage backend
- Add lanes, use drag & drop to order ideas
- Add comments to ideas
- Export your generated ideas to html or csv (currently comma separated)
- German & English Translation files
- By default, brainstormings are deleted after 30 days to ensure GDPR compliancy

![](docs/screenshot.png)
![](docs/screenshot2.png)

## Use-cases

Brainstorm ...

- ... new business ideas
- ... solutions for a problem
- ... what to eat tonight
- ...

## Getting Started

mindwendel can be run just about anywhere. So checkout our [Installation Guides](./docs/installing_mindwendel.md) for detailed instructions for various deployments. The easiest way to deploy and run mindwendel is using our own `docker-compose-prod.yml` file. For instructions, see [Setup for Production](#setup-for-production).
If you want to contribute, jump ahead to [Development](#development)!

## Contributing

To get started with a development installation of mindwendel, follow the instructions below.

mindwendel is built on top of:

- [Elixir](https://elixir-lang.org/install.html)
- [Phoenix Framework](https://hexdocs.pm/phoenix/installation.html#phoenix)
- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view)
- [PostgreSQL](https://www.postgresql.org)

### Workflow

1. Fork it (<https://github.com/mindwendel/mindwendel/fork>)
2. Create your feature branch (`git checkout -b fooBar`)
3. Commit your changes (`git commit -am 'Add some fooBar'`)
4. Push to the branch (`git push origin fooBar`)
5. Create a new Pull Request

### Development

- Startup docker compose setup

  ```bash
  docker compose up --build -d
  ```

- Setup the database

  ```bash
  docker compose exec app mix ecto.setup
  ```

- Start the server

```bash
  docker compose exec app mix phx.server
```

- Go to http://localhost:4000/

- Open you favorite editor and start developing

- Open a shell in the docker container to execute tests, etc.

  ```bash
  docker compose exec app bash
  ```

- Go to http://localhost:4000/

#### Localization

You can extract new strings to translate by running:

```bash
mix gettext.extract --merge
```

### Testing

- Startup docker compose setup

  ```bash
  docker compose up --build -d
  ```

- Run the test

  ```bash
  docker compose exec app mix test
  ```

### Setup for Production

- Generate self-signed ssl sertificate for the postgres server on the host machine; the generated files are mounted into the docker container

  ```bash
  mkdir -p ./ca
  openssl req -new -text -passout pass:abcd -subj /CN=localhost -out ./ca/server.req -keyout ./ca/privkey.pem
  openssl rsa -in ./ca/privkey.pem -passin pass:abcd -out ./ca/server.key
  openssl req -x509 -in ./ca/server.req -text -key ./ca/server.key -out ./ca/server.crt
  chmod 600 ./ca/server.key
  test $(uname -s) = Linux && chown 70 ./ca/server.key
  ```

- Duplicate and rename `.env.prod.default`

  ```bash
  cp .env.prod.default .env.prod
  ```

- Adjust all configs in `.env.prod`, e.g. database settings, ports, disable ssl env vars if necessary

- Start everything at once (including a forced build):

  ```bash
  docker compose --file docker-compose-prod.yml --env-file .env.prod up -d --build --force-recreate
  ```

- Open the browser and go to `http://${URL_HOST}`

#### Note

- The url has to match the env var `URL_HOST`; so http://localhost will not work when your `URL_HOST=0.0.0.0`
- The mindwendel production configuration is setup to enforce ssl, see Mindwendel.Endpoint configuration in `config/prod.exs`
- The mindwendel production configuration supports deployment behind a reverse porxy (load balancer) by parsing the proper protocol from the x-forwarded-\* header of incoming requests, see `config/prod.exs`
- If you are having troubles during setup, please raise an issue.

### Build release and production docker image

- Build the docker image based on our Dockerfile
  ```bash
  docker build -t mindwendel_prod .
  ```

### Formatting

We are using Elixir's built-in formatter.

- Check if the code is properly formatted
  ```bash
  mix format --check-formatted
  ```
- Automatically format the code
  ```bash
  mix format
  ```

## Feature flags

### Privacy and automatic data removal
Mindwendel includes a job runner that deletes old brainstormings after a defined number of days. This can be controlled with the setting `MW_FEATURE_BRAINSTORMING_REMOVAL_AFTER_DAYS`, which can be set to for instance to `30`.

### File Storage
File storage is available through an s3 compatible object storage backend. An encryption key (`VAULT_ENCRYPTION_KEY_BASE64`) needs to be generated before, e.g.:

```
iex
32 |> :crypto.strong_rand_bytes() |> Base.encode64()
```

or

```
openssl rand -base64 32
```

Then, object storage and the vault key need to be set:

```
OBJECT_STORAGE_BUCKET: mindwendel
OBJECT_STORAGE_SCHEME: "http://"
OBJECT_STORAGE_HOST: minio
OBJECT_STORAGE_PORT: 9000
OBJECT_STORAGE_REGION: local
OBJECT_STORAGE_USER: ...
OBJECT_STORAGE_PASSWORD: ...
VAULT_ENCRYPTION_KEY_BASE64: ...
```

There is an example given inside the `docker-compose.yml` with a docker compose minio setup.

To deactivate file storage, use `MW_FEATURE_IDEA_FILE_UPLOAD` (defaults to `true`) and set it to `false`.

### Localization

Currently, there are two language files available, german (`de`) and english (`en`). To set the default_locale, you can set `MW_DEFAULT_LOCALE`. The default is english.

## Testimonials

<img src="https://www.nibis.de/img/nlq-medienbildung.png" align="left" style="margin-right:20px">
<img src="https://kits.blog/wp-content/uploads/2021/03/kits_logo.svg" width=100px align="left" style="margin-right:20px">

kits is a project platform hosted by a public institution for quality
development in schools (Lower Saxony, Germany) and focusses on digital tools
and media in language teaching. mindwendel is used in workshops to activate
prior knowledge, and collect and structure ideas. In addition, mindwendel can
be found on https://kits.blog/tools and can be used by schools for free. More info on
how to use it can be found in this post https://kits.blog/digitale-lesestrategien-brainstorming/

Logos and text provided with courtesy of kits.

## Acknowledgements

- https://github.com/JannikStreek
- https://github.com/gerardo-navarro
- https://github.com/nwittstruck
- Lightbulb stock image by LED Supermarket at Pexels: https://www.pexels.com/de-de/foto/die-gluhbirne-577514/

## Image Licenses
- Lightbulb, Pexels / CC0: https://www.pexels.com/license/, https://www.pexels.com/terms-of-service/
- GitHub Logo: https://github.com/logos
