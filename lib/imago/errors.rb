# frozen_string_literal: true

module Imago
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class ApiError < Error
    attr_reader :status_code, :response_body

    def initialize(message, status_code: nil, response_body: nil)
      @status_code = status_code
      @response_body = response_body
      super(message)
    end
  end

  class AuthenticationError < ApiError; end

  class RateLimitError < ApiError; end

  class InvalidRequestError < ApiError; end

  class ProviderNotFoundError < Error; end
end
