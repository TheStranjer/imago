# frozen_string_literal: true

module Imago
  class Client
    PROVIDERS = {
      openai: Providers::OpenAI,
      gemini: Providers::Gemini,
      xai: Providers::XAI
    }.freeze

    attr_reader :provider, :model

    def initialize(provider:, model: nil, api_key: nil)
      @provider_name = provider.to_sym
      @model = model
      @api_key = api_key

      validate_provider!
      @provider = build_provider
    end

    def generate(prompt, opts = {})
      provider.generate(prompt, opts)
    end

    def models
      provider.models
    end

    private

    def validate_provider!
      return if PROVIDERS.key?(@provider_name)

      raise ProviderNotFoundError, "Unknown provider: #{@provider_name}. " \
                                   "Available providers: #{PROVIDERS.keys.join(', ')}"
    end

    def build_provider
      PROVIDERS[@provider_name].new(model: @model, api_key: @api_key)
    end
  end
end
