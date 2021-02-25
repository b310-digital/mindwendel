# kits version of mindwendel

This project includes a few CI changes to the mindwendel software. To limit the merging overhead to include updates from the main mindwendel repo, most changed files are replaced ONLY during the docker build:

- `_bootstrap_custom.scss` => `kits_bootstrap_custom.scss` for colors
- `home.html.leex` => `kits_home.html.leex` as new starting page
- `static_page.html.leex` => `kits_static_page.html.leex` as new starting page layout which includes 2 new css files (`kits.css` and `kits_home.css` - taken from other kits projects. These files are copied to /priv/static/css)
- `mindwendel_logo_black.svg` => `noun_bulb.svg` as new icon
- `favicon` => `kits_favicon` as new favicon
- New svg images / other icons prefixed with `kits_`

If development occurs more frequently, these files should be integrated normally - resulting in modified files. Changes from the mindwendel main repo then have to be merged or rebased.

## Development

To simulated local development, exchange the following files:

Change the static_page_controller inside mindwendel_web/controllers as follows:

```elixir
plug :put_root_layout, {MindwendelWeb.LayoutView, :kits_static_page}
```

```elixir
    render(conn, "kits_home.html",
      current_user: current_user,
      brainstorming: %Brainstorming{},
      changeset: Brainstormings.change_brainstorming(%Brainstorming{}, %{})
    )
```

Move the raw css files (kits_home.css / kits.css) to /priv/static/css.

Thats it.

## Installation

Use docker-compose
```sh
docker-compose -f docker-compose-kits.yml up
```

or to make sure updates will be included:

```sh
docker-compose -f docker-compose-kits.yml --force-recreate up
```

Important: Make sure to exchange passwords with proper ones!


See main README for project specifics.
