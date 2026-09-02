# Onetimer

![CI](https://github.com/z19r/onetimer/actions/workflows/ci.yml/badge.svg)
[![Gem](https://badge.fury.io/rb/onetimer.svg)](https://rubygems.org/gems/onetimer)
<img src="https://zrkonium.mudskipper-typhon.ts.net/pixel.gif?owner=z19r&repo=onetimer"/>

Runs one-off data tasks exactly once, the way `db:migrate` runs schema
migrations exactly once — safe to run repeatedly, safe across concurrent
deploy machines.

**Views:** <!--COUNTER:START-->4<!--COUNTER:END-->

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

A task's identity is its filename (minus the timestamp). Renaming a task file after it may have run on any machine creates a new identity and causes the task to run twice — once under the old name and once under the new name. If you need to change a task, do it before it has run anywhere. Once a task has potentially run, never rename its file.

Once a task is marked completed, editing its file has no effect. The `Runner` only checks whether a `Task` record exists for that filename; the file's contents are never examined. To change the logic of an already-completed task, write a new task file instead of editing the old one.

Run pending tasks (idempotent — already-completed tasks are skipped):

```bash
bin/rake onetimer:run
```

Typically wired into your deploy entrypoint alongside `db:migrate`. Use
`bin/rake onetimer:doctor` to verify the required unique index exists, and
`bin/rake onetimer:pending` to list what would run without running it — see
[docs/GUIDE.md](docs/GUIDE.md#running-tasks) for details.

### Task ordering

Tasks run in filename-sort order, which is why the generator prefixes files
with a timestamp. The timestamp is what makes that order meaningful and
predictable — do not rename a task file to remove or reorder its timestamp
once any machine may have run it. See [Gotchas —
ordering](docs/GUIDE.md#tasks-run-in-filename-sort-order-6) in the full guide
for details.

## Configuration

Tasks live in `lib/one_timers/` by default. Override in an initializer:

```ruby
Rails.application.config.onetimer.tasks_dir = Rails.root.join("lib/data_tasks")
```

Failed tasks are destroyed by default so they retry on the next deploy. Opt
into keeping a `failed` row with the error message instead:

```ruby
Rails.application.config.onetimer.record_failures = true
```

Existing apps need a migration first: `add_column :onetimer_tasks,
:error_message, :text`.

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
