# Onetimer

![CI](https://github.com/z19r/onetimer/actions/workflows/ci.yml/badge.svg)
[![Gem](https://badge.fury.io/rb/onetimer.svg)](https://rubygems.org/gems/onetimer)

Runs one-off data tasks exactly once, the way `db:migrate` runs schema
migrations exactly once — safe to run repeatedly, safe across concurrent
deploy machines.

**Views:** <!--COUNTER:START-->0<!--COUNTER:END-->

## Installation

```ruby
gem "onetimer"
```

```bash
bundle install
bin/rails generate onetimer:install
bin/rails db:migrate
```

The generator adds a migration for the `onetimer_tasks` tracking table and
creates `lib/one_timers/`.

## Usage

Generate a task:

```bash
bin/rake onetimer:new NAME=backfill_something
```

This creates `lib/one_timers/<timestamp>_backfill_something.rb`:

```ruby
module OneTimers
  class BackfillSomething
    def run
      # One-time task logic goes here.
    end
  end
end
```

Run pending tasks (idempotent — already-completed tasks are skipped):

```bash
bin/rake onetimer:run
```

Typically wired into your deploy entrypoint alongside `db:migrate`.

## Configuration

Tasks live in `lib/one_timers/` by default. Override in an initializer:

```ruby
Rails.application.config.onetimer.tasks_dir = Rails.root.join("lib/data_tasks")
```

## Gotchas

See [docs/GUIDE.md](docs/GUIDE.md#gotchas) for known sharp edges (renaming
files, retry behavior, ordering, etc.).

## Development

```bash
just setup
just test
just lint
```

## Releasing

```bash
just release-dry-run patch   # preview + quality gate
just release patch           # bump, PR, merge, tag, publish
```

`just release` takes `patch`, `minor`, or `major`. It bumps
`lib/onetimer/version.rb`, opens a release PR, waits for CI, merges,
tags `vX.Y.Z`, and watches `.github/workflows/publish.yml` push to
RubyGems.org.

One-time setup: add a RubyGems.org API key (Account → API Keys, scoped to
"Push rubygem") as the `RUBYGEMS_API_KEY` secret in the repo's Actions
settings.

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/z19r/onetimer>.

## 📖 GuestBook — 0 Entries

Open an issue with the `guestbook` label to sign.

<!-- GUESTBOOK:START -->
<!-- GUESTBOOK:END -->
