# Onetimer Guide

A tiny Rails engine that runs one-off data tasks exactly once — the way
`db:migrate` runs schema migrations exactly once — safely across any number
of concurrent deploy machines.

## Contents

- [Architecture](#architecture)
- [Installation](#installation)
- [Running tasks](#running-tasks)
- [Configuration](#configuration)
- [Supported databases](#supported-databases)
- [Gotchas](#gotchas)

## Architecture

Three moving pieces:

- `Onetimer::Task` (`app/models/onetimer/task.rb`) — an `ActiveRecord`
model backed by the `onetimer_tasks` table. One row per task, tracking
`name`, `status` (`running` / `completed`), `started_at`, `finished_at`.
A unique index on `name` is what makes the whole thing safe.
- `Onetimer::Runner` (`lib/onetimer/runner.rb`) — the engine. It scans
`Onetimer.tasks_dir` for `*.rb` files, and for each one:
  1. Skips it if a `completed` row already exists for that file's name.
  2. **Claims** the task by inserting a `running` row. Two processes racing
    to claim the same task hit the unique index — only one `INSERT`
     succeeds, so only one process actually runs it.
  3. `require`s the file, instantiates `OneTimers::<ClassName>`, calls
    `#run`.
  4. Marks the row `completed` on success, or destroys the row and
    re-raises on failure (so a fixed version of the task can be retried
     on the next deploy).
- `Onetimer::Engine` (`lib/onetimer/engine.rb`) — a standard Rails
engine (`isolate_namespace Onetimer`) that wires up `config.onetimer` and
loads the rake tasks.

There's no scheduler, no background worker, and no polling — `Runner` does
its work synchronously when invoked, exactly like `rails db:migrate`.

```bash
lib/one_timers/20260115120000_backfill_something.rb
        │
        ▼
Runner.run_pending! ──> claim row in onetimer_tasks (unique on name)
        │                       │
        │                won by one process
        ▼                       ▼
  require + OneTimers::BackfillSomething.new.run
        │
        ▼
  mark row completed  (or destroy row + raise on error)
```

## Installation

```ruby
# Gemfile
gem "onetimer"
```

```bash
bundle install
bin/rails generate onetimer:install
bin/rails db:migrate
```

The generator (`lib/generators/onetimer/install/install_generator.rb`)
creates:

- a migration for the `onetimer_tasks` table
- an empty `lib/one_timers/` directory

## Running tasks

Generate a task:

```bash
bin/rake onetimer:new NAME=backfill_something
```

This writes `lib/one_timers/<timestamp>_backfill_something.rb`:

```ruby
module OneTimers
  class BackfillSomething
    def run
      # One-time task logic goes here.
    end
  end
end
```

The class name is derived from the filename minus the leading timestamp
(`<timestamp>_backfill_something.rb` → `OneTimers::BackfillSomething`), so
don't rename the file after generating it without also renaming the class.

Run everything pending:

```bash
bin/rake onetimer:run
```

Idempotent — already-`completed` tasks are skipped. Wire it into your
deploy entrypoint right alongside `db:migrate`.

## Configuration

Two settings, set in an initializer:

```ruby
# config/initializers/onetimer.rb
Rails.application.config.onetimer.tasks_dir = Rails.root.join("lib/data_tasks")
Rails.application.config.onetimer.record_failures = true
```

`tasks_dir` defaults to `Rails.root.join("lib/one_timers")`
(`lib/onetimer/engine.rb`).

`record_failures` defaults to `false`: a failed task's row is destroyed so
it retries on the next deploy. Set it to `true` to instead keep the row
marked `failed` with `error_message` set. Existing apps must add that
column first (`add_column :onetimer_tasks, :error_message, :text`) — if
`record_failures` is enabled without it, `Runner` logs a warning and falls
back to destroying the row.

There's currently no config for things like a custom table name — `Task`
hardcodes the `onetimer_tasks` table.

## Supported databases

`Onetimer::Task` is a plain `ActiveRecord` model using only standard column
types (`string`, `datetime`, timestamps) and a unique index — nothing
Postgres/MySQL/SQLite-specific. It works on **any database Rails/
ActiveRecord supports**: PostgreSQL, MySQL/MariaDB, SQLite, and anything
else with a working AR adapter. The only real requirement is that unique
index enforcement works (true for all mainstream adapters), since that's
what prevents two deploy machines from double-running a task.

## Gotchas

Known sharp edges when using Onetimer. Each entry links to a GitHub
issue for discussion and possible fixes.

See also [docs/GUIDE.md](docs/GUIDE.md#gotchas).

### Renaming task files can cause double-runs (#1)

<https://github.com/z19r/onetimer/issues/1>

Renaming a task file after it ran is a no-op the second time, but a
disaster if done before it runs on every machine. The task's identity
*is* its filename (minus timestamp). Renaming after some machines have
run it but before others have will cause it to run twice under two
different names.

### Failed tasks leave no persistent failure record (#2)

<https://github.com/z19r/onetimer/issues/2>

By default a failed task's row is still destroyed, not marked `failed` —
that's intentional, it lets you fix the task and retry on the next deploy.
Opt into keeping a persistent `failed` row with the error message via
`Onetimer.record_failures` (see [Configuration](#configuration)); without
that opt-in, check `Rails.logger` output at deploy time.

### Editing completed task files has no effect (#3)

<https://github.com/z19r/onetimer/issues/3>

Editing a task file after it is marked `completed` does nothing.
`Runner` only checks the filename, never the file contents or checksum.
Once completed, that name is permanently skipped — write a new task
file instead of editing an old one.

### Unique index on name is required (#4)

<https://github.com/z19r/onetimer/issues/4>

Concurrency safety depends entirely on the unique index on `name`. If
you hand-roll the migration instead of using the generator and forget
`add_index :onetimer_tasks, :name, unique: true`, two concurrent deploy
machines can both run the same task.

### No dry-run or pending listing mode (#5)

<https://github.com/z19r/onetimer/issues/5>

No dry-run mode. `bin/rake onetimer:run` executes pending tasks
immediately; there is no `--check` or `--pending` listing built in
today.

### Tasks run in filename sort order (#6)

<https://github.com/z19r/onetimer/issues/6>

Tasks run in filename order (`Dir.glob(...).sort`), which is why the
generator prefixes files with a timestamp — do not break that ordering
by renaming files to remove or reorder the timestamp.
