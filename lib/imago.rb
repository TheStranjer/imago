# frozen_string_literal: true

require 'faraday'
require 'json'

require_relative 'imago/version'
require_relative 'imago/errors'
require_relative 'imago/providers/base'
require_relative 'imago/providers/openai'
require_relative 'imago/providers/gemini'
require_relative 'imago/providers/xai'
require_relative 'imago/client'

module Imago
  class << self
    def new(provider:, model: nil, api_key: nil)
      Client.new(provider: provider, model: model, api_key: api_key)
    end
  end
end
