# mindwendel

A real-time collaborative brainstorming web application built with Elixir and Phoenix LiveView.

## Tech Stack

- **Language**: Elixir 1.17
- **Framework**: Phoenix 1.7.21
- **UI**: Phoenix LiveView (real-time updates)
- **Database**: PostgreSQL
- **Deployment**: Docker & docker-compose

## Project Structure

```
lib/
├── mindwendel/              # Core business logic (contexts)
│   ├── brainstormings.ex    # Brainstorming sessions
│   ├── ideas.ex             # Ideas within brainstormings
│   ├── lanes.ex             # Kanban-style lanes
│   ├── accounts.ex          # User management
│   ├── comments.ex          # Comments on ideas
│   ├── attachments.ex       # File/link attachments
│   └── services/            # S3 storage, vault encryption
├── mindwendel_web/          # Web layer
│   ├── router.ex            # Route definitions
│   ├── live/                # LiveView components
│   └── controllers/         # HTTP controllers
config/                      # Environment configuration
priv/repo/migrations/        # Database migrations
test/                        # Test files
```

## Key Files

- `lib/mindwendel_web/router.ex` - All routes and pipelines
- `lib/mindwendel_web/live/brainstorming_live/show.ex` - Main brainstorming UI
- `lib/mindwendel/brainstormings.ex` - Core brainstorming logic
- `lib/mindwendel/ideas.ex` - Idea CRUD and positioning
- `config/config.exs`, `config/dev.exs`, `config/prod.exs` - Configuration
- `mix.exs` - Dependencies and project settings

## Development Commands

```bash
# Setup database
mix ecto.setup

# Start Phoenix server
mix phx.server

# Run tests
mix test

# Format code
mix format

# Update translations
mix gettext.extract --merge
```

Access at: http://localhost:4000

## Development Flow
Important: After every feature, plase execute the following commands and make sure they pass correctly:
- `mix test`
- `mix credo`
- `mix format`
- `mix gettext.extract --merge`

## Key Concepts

- **Brainstorming**: A session where users collaborate
- **Ideas**: Individual thoughts/items within a brainstorming
- **Lanes**: Kanban-style columns to organize ideas
- **Labels**: Tags/categories for filtering ideas
- **Comments**: Discussion on specific ideas
- **Likes**: Upvoting mechanism for ideas

## Environment Variables
See `.env.default` for complete list.