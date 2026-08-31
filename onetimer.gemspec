# frozen_string_literal: true

require_relative "lib/onetimer/version"

Gem::Specification.new do |spec|
  spec.name = "onetimer"
  spec.version = Onetimer::VERSION
  spec.authors = ["Zack Kitzmiller"]
  spec.email = ["zackkitzmiller@gmail.com"]

  spec.summary = "Runs one-off data tasks exactly once, the way db:migrate runs schema migrations."
  spec.description = "A tiny Rails engine that gives you a lib/one_timers/ directory of run-once " \
                      "data tasks, tracked in the database so each one runs exactly once across " \
                      "any number of deploy machines."
  spec.homepage = "https://github.com/z19r/onetimer"
  spec.required_ruby_version = ">= 3.2.0"
  spec.license = "Nonstandard"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rails", ">= 7.0"
end
