## Onetimer — development workflows

# First-time setup: install dependencies
setup:
    bundle install

# Run the test suite
test:
    bundle exec rake test

# Run RuboCop
lint:
    bundle exec rubocop

# Auto-fix RuboCop offenses where safe
lint-fix:
    bundle exec rubocop -a

# Run tests + lint (mirrors the default rake task)
build:
    bundle exec rake

# Open an interactive console with the gem loaded
console:
    bin/console

# Remove generated test artifacts
clean:
    rm -rf test/dummy/db/*.sqlite3 test/dummy/log coverage pkg

# Bump version, tag, and push a new release to RubyGems (bundle exec rake release)
release:
    bundle exec rake release
