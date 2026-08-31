# Onetimer

Runs one-off data tasks exactly once, the way `db:migrate` runs schema
migrations exactly once — safe to run repeatedly, safe across concurrent
deploy machines.

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

1. Bump `Onetimer::VERSION` in `lib/onetimer/version.rb`, commit.
2. `just release` — tags the commit and pushes the tag.
3. CI (`.github/workflows/publish.yml`) builds the gem and pushes it to
   RubyGems.org using the `RUBYGEMS_API_KEY` repo secret.

One-time setup: add a RubyGems.org API key (Account → API Keys, scoped to
"Push rubygem") as the `RUBYGEMS_API_KEY` secret in the repo's Actions
settings.

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/z19r/onetimer>.
