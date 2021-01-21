# mindwendel

![Workflow Status Badge](https://github.com/mindwendel/mindwendel/workflows/ci_cd/badge.svg)

Grab your post-its. Ready? Brainstorm. mindwendel helps you to easily brainstorm and upvote ideas and thoughts within your team. Built from scratch with [Phoenix](https://www.phoenixframework.org).

![](docs/screenshot.png)
![](docs/screenshot2.png)

## Getting Started

### Prerequisites

- [Elixir](https://elixir-lang.org/install.html)
- [Phoenix Framework](https://hexdocs.pm/phoenix/installation.html#phoenix)
- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view)
- [PostgreSQL](https://www.postgresql.org)

### For local setup and development

- Clone the repo
  ```sh
  git clone https://github.com/github_username/repo_name.git
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
  ```ah
  mix ecto.setup
  ```
- Install NPM packages
  ```sh
  npm --prefix assets install
  ```
- Start the phoenix server
  ```sh
  mix phx.server
  ```
- Go to [http://localhost:4000/]

### For docker development

`docker-compose build`
`docker-compose up`

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
2. Create your feature branch (`git checkout -b feature/fooBar`)
3. Commit your changes (`git commit -am 'Add some fooBar'`)
4. Push to the branch (`git push origin feature/fooBar`)
5. Create a new Pull Request

## Acknowledgements

- https://github.com/JannikStreek
- https://github.com/gerardo-navarro
- https://github.com/nwittstruck
- Lightbulb stock image by LED Supermarket at Pexels: https://www.pexels.com/de-de/foto/die-gluhbirne-577514/
