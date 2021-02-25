# kits version of mindwendel

This project includes a few CI changes to the mindwendel software. To limit the merging overhead to include updates from the main mindwendel repo, most changed files are replaced ONLY during the docker build:

- `_bootstrap_custom.scss` => `kits_bootstrap_custom.scss` for colors
- `home.html.leex` => `kits_home.html.leex` as new starting page
- `static_page.html.leex` => `kits_static_page.html.leex` as new starting page layout which includes 2 new css files (`kits.css` and `kits_home.css` - taken from other kits projects. These files are copied to /priv/static/css)
- `mindwendel_logo_black.svg` => `noun_bulb.svg` as new icon
- `favicon` => `kits_favicon` as new favicon
- New svg images / other icons prefixed with `kits_`

## Development

Exchange the files mentioned at the top with their counterparts, or copy e.g. the html files in the same folders like their counterparts and change the static_controller.ex to use these files (layout and home).

Move the raw css files to /priv/static/css.

If you need more information on where to move the files, please have a look at the docker build file Dockerfile_Kits.

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
