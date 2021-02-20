# kits version of mindwendel

This project includes a few CI changes to the mindwendel software. To limit the merging overhead to include updates from the main mindwendel repo, most changed files are replaced ONLY during the docker build:

- `_bootstrap_custom.scss` => `kits_bootstrap_custom.scss` for colors
- `home.html.leex` => `kits_home.leex.html` as new starting page
- `static_page.html.leex` => `kits_static_page.leex.html` as new starting page layout which includes 2 new css files from priv/static/css
- `mindwendel_logo_black.svg` => `noun_bulb.svg` as new icon

See main README for project specifica.
