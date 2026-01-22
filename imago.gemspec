# frozen_string_literal: true

require_relative 'lib/imago/version'

Gem::Specification.new do |spec|
  spec.name = 'imago'
  spec.version = Imago::VERSION
  spec.authors = ['NEETzsche']
  spec.email = ['thestranjer@protonmail.com']

  spec.summary = 'A unified Ruby interface for multiple image generation AI providers'
  spec.description = 'Imago provides a simple, unified API to generate images using various AI providers ' \
                     'including OpenAI (DALL-E), Google Gemini, and xAI (Grok).'
  spec.homepage = 'https://github.com/example/imago'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?('bin/', 'test/', 'spec/', 'features/', '.git', '.github', 'appveyor', 'Gemfile')
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'base64', '~> 0.2'
  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'faraday-multipart', '~> 1.0'
end
