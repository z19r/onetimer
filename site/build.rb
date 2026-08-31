#!/usr/bin/env ruby
# frozen_string_literal: true

require "erb"
require "fileutils"

ROOT = __dir__
SRC = File.join(ROOT, "src")
DIST = File.join(ROOT, "dist")

PAGES = {
  "index.html" => {
    src: "pages/index.html.erb",
    nav: "home",
    title: "Onetimer &mdash; run one-off data tasks exactly once",
    description: "A tiny Rails engine that runs one-off data tasks exactly " \
                 "once, the way db:migrate runs schema migrations exactly " \
                 "once, safely across any number of deploy machines."
  },
  "docs/index.html" => {
    src: "pages/docs.html.erb",
    nav: "docs",
    title: "Onetimer Documentation",
    description: "Installation, usage, configuration, database support, " \
                 "and gotchas for Onetimer."
  }
}.freeze

FileUtils.rm_rf(DIST)
FileUtils.mkdir_p(DIST)

layout = ERB.new(File.read(File.join(SRC, "layout.html.erb")))

PAGES.each do |out_path, meta|
  title = meta.fetch(:title)
  description = meta.fetch(:description)
  nav = meta.fetch(:nav)
  body = ERB.new(File.read(File.join(SRC, meta.fetch(:src)))).result(binding)
  html = layout.result(binding)

  dest = File.join(DIST, out_path)
  FileUtils.mkdir_p(File.dirname(dest))
  File.write(dest, html)
end

FileUtils.cp_r(File.join(ROOT, "assets"), File.join(DIST, "assets"))

puts "Built #{PAGES.size} pages into #{DIST}"
