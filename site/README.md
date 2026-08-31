# onetimer.z19r.com

Marketing site, deployed via Netlify (see `../netlify.toml`, base directory
`site`). Design tokens and components are synced from the "Onetimer Design
System" Claude Design project — re-pull with `/design-sync` if the source
project changes.

## Build

```bash
ruby build.rb
```

Renders `src/pages/*.html.erb` through `src/layout.html.erb` into `dist/`,
and copies `assets/` alongside them. Netlify runs this same command at
deploy time (`dist` is gitignored, not committed).

## Structure

- `src/layout.html.erb` &mdash; shared head/header/footer, including the
  Umami analytics snippet (loaded on every page).
- `src/pages/*.html.erb` &mdash; page bodies.
- `assets/css/tokens.css` &mdash; design tokens (colors, type, spacing).
- `assets/css/site.css` &mdash; layout and component styles.
- `assets/js/site.js` &mdash; copy-to-clipboard for code blocks.
