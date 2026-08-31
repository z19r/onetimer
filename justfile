# Onetimer — development workflows
# https://github.com/casey/just

set dotenv-load := false

version := `ruby -Ilib -e 'require "onetimer/version"; puts Onetimer::VERSION'`

default:
    @just --list --unsorted

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

# ─── Release ─────────────────────────────────────────────────────

# Release quality gate (test + lint)
release-check:
    bundle exec rake

# Preview what a release would do without changing anything
release-dry-run LEVEL:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! "{{ LEVEL }}" =~ ^(patch|minor|major)$ ]]; then
        echo "Usage: just release-dry-run patch|minor|major"; exit 1
    fi
    CURRENT=$(ruby -Ilib -e 'require "onetimer/version"; puts Onetimer::VERSION')
    echo "Current version: $CURRENT"
    echo "Bump level: {{ LEVEL }}"
    just release-check
    echo ""
    echo "All checks passed. Run: just release {{ LEVEL }}"

# Bump version, create release branch + PR, tag, publish (requires: gh)
release LEVEL: release-check
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! "{{ LEVEL }}" =~ ^(patch|minor|major)$ ]]; then
        echo "Usage: just release patch|minor|major"; exit 1
    fi
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Error: dirty working tree"; exit 1
    fi
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$BRANCH" != "main" ]]; then
        read -r -p "Not on main (currently on $BRANCH). Switch to main? [y/N] " REPLY || REPLY=""
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
            git checkout main
        else
            echo "Aborted: release must run from main"; exit 1
        fi
    fi
    git pull --ff-only origin main
    OLD_VERSION=$(ruby -Ilib -e 'require "onetimer/version"; puts Onetimer::VERSION')
    IFS='.' read -r MAJ MIN PAT <<< "$OLD_VERSION"
    case "{{ LEVEL }}" in
        patch) PAT=$((PAT + 1)) ;;
        minor) MIN=$((MIN + 1)); PAT=0 ;;
        major) MAJ=$((MAJ + 1)); MIN=0; PAT=0 ;;
    esac
    VERSION="${MAJ}.${MIN}.${PAT}"
    if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
        echo "Error: tag v${VERSION} already exists"
        echo "Delete the bad tag or bump manually before releasing."
        exit 1
    fi
    sed -i "s/VERSION = \"[^\"]*\"/VERSION = \"${VERSION}\"/" \
        lib/onetimer/version.rb
    echo "Bumped ${OLD_VERSION} -> ${VERSION}"
    git checkout -b "release/v${VERSION}"
    git add lib/onetimer/version.rb
    git commit -m "release: v${VERSION}"
    git push -u origin "release/v${VERSION}"
    gh pr create \
        --title "release: v${VERSION}" \
        --body "Bump to v${VERSION} ({{ LEVEL }} release)" \
        --base main

    echo "Waiting for CI checks to appear..."
    for i in $(seq 1 30); do
        if gh pr checks --json name 2>/dev/null | grep -q name; then break; fi
        sleep 2
    done
    echo "Watching CI checks..."
    gh pr checks --watch --fail-fast

    echo "CI passed. Merging..."
    gh pr merge --squash --delete-branch

    git checkout main
    git pull --ff-only origin main

    # Re-read version from merged main (squash may differ from branch tip).
    VERSION=$(ruby -Ilib -e 'require "onetimer/version"; puts Onetimer::VERSION')
    if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
        echo "Error: tag v${VERSION} already exists after merge"
        exit 1
    fi
    git tag "v${VERSION}"
    git push origin "v${VERSION}"

    echo "Watching publish workflow..."
    gh run watch --workflow publish.yml

    echo ""
    echo "Release v${VERSION} complete."
