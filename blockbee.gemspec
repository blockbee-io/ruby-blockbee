# frozen_string_literal: true

require_relative "lib/blockbee"

Gem::Specification.new do |spec|
  spec.name = "blockbee"
  spec.version = BlockBee::VERSION
  spec.authors = ["BlockBee"]
  spec.email = ["info@blockbee.io"]

  spec.summary = "Ruby implementation of BlockBee's payment gateway"

  spec.homepage = "https://blockbee.io"
  spec.required_ruby_version = ">= 3.0.0"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/blockbee-io/ruby-blockbee"
  spec.metadata["changelog_uri"] = "https://github.com/blockbee-io/ruby-blockbee/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
