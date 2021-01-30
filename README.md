# mindwendel

![Workflow Status Badge](https://github.com/mindwendel/mindwendel/workflows/ci_cd/badge.svg)

Create a challenge. Ready? Brainstorm. mindwendel helps you to easily brainstorm and upvote ideas and thoughts within your team. Built from scratch with [Phoenix](https://www.phoenixframework.org).

## Features
- Anonymously invite people to your brainstorming - no registration needed. Usernames are optional.
- Easily create and upvote ideas, with live updates from your companions.
- Preview of links to ease URL sharing
- Cluster your ideas with labels
- Export your generated ideas to html or csv (currently comma separated)

![](docs/screenshot.png)
![](docs/screenshot2.png)

## Use-cases
Brainstorm ...
- ... new business ideas
- ... solutions for a problem
- ... what to eat tonight
- ... 

## Getting Started

### Prerequisites

- [Elixir](https://elixir-lang.org/install.html)
- [Phoenix Framework](https://hexdocs.pm/phoenix/installation.html#phoenix)
- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view)
- [PostgreSQL](https://www.postgresql.org)

### For local setup and development

- Clone the repo
  ```sh
  git clone https://github.com/mindwendel/mindwendel.git
  ```
- Install dependencies with
  ```sh
  mix deps.get
  ```
- Copy and adjust local env variables, e.g. DATABASE_USER, DATABASE_NAME, etc.
  ```sh
  cp .env.default .env
  ```
- Load your env variables; NOTE: Always do this when your env settings change or your open a new terminal session
  ```sh
  source .env
  ```
- Create and migrate your database with
  ```sh
  mix ecto.setup
  ```
- Add seeds with
  ```sh
  mix run priv/repo/seeds.exs
  ```
- Install NPM packages
  ```sh
  npm --prefix assets install
  ```
- Start the phoenix server
  ```sh
  mix phx.server
  ```
- Go to http://localhost:4000/

### For docker development

```sh
docker-compose build
```

```sh
docker-compose up
```

To browse the container, use e.g.:

```sh
docker exec -it mindwendel sh
```

## Usage example

## Development setup

For local development, please follow [the guide for local development setup](#for-local-setup-and-development).

### Testing

- Load the env variables for testing
  ```sh
  source .env
  ```
- Ensure your database is running and reset your database
  ```sh
  MIX_ENV=test mix ecto.reset
  ```
- Run the test
  ```sh
  mix test
  ```

### Formatting

We are using Elixir's built-in formatter.

- Check if the code is properly formatted
  ```sh
  mix format --check-formatted
  ```
- Automatically format the code
  ```sh
  mix format
  ```

## Contributing

1. Fork it (<https://github.com/mindwendel/mindwendel/fork>)
2. Create your feature branch (`git checkout -b fooBar`)
3. Commit your changes (`git commit -am 'Add some fooBar'`)
4. Push to the branch (`git push origin fooBar`)
5. Create a new Pull Request

## Acknowledgements

- https://github.com/JannikStreek
- https://github.com/gerardo-navarro
- https://github.com/nwittstruck
- Lightbulb stock image by LED Supermarket at Pexels: https://www.pexels.com/de-de/foto/die-gluhbirne-577514/
