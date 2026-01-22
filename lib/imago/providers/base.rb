# frozen_string_literal: true

module Imago
  module Providers
    class Base
      attr_reader :model, :api_key

      def initialize(model: nil, api_key: nil)
        @model = model || default_model
        @api_key = api_key || fetch_api_key
        validate_api_key!
      end

      def generate(_prompt, _opts = {})
        raise NotImplementedError, "#{self.class} must implement #generate"
      end

      def models
        raise NotImplementedError, "#{self.class} must implement #models"
      end

      protected

      def default_model
        raise NotImplementedError, "#{self.class} must implement #default_model"
      end

      def env_key_name
        raise NotImplementedError, "#{self.class} must implement #env_key_name"
      end

      def fetch_api_key
        ENV.fetch(env_key_name, nil)
      end

      def validate_api_key!
        return if api_key && !api_key.empty?

        raise ConfigurationError,
              "API key is required. Set #{env_key_name} environment variable or pass api_key option."
      end

      def connection(base_url)
        Faraday.new(url: base_url) do |conn|
          conn.request :json
          conn.response :json
          conn.adapter Faraday.default_adapter
        end
      end

      def handle_response(response)
        return response.body if response.status.between?(200, 299)

        raise_response_error(response)
      end

      def raise_response_error(response)
        error_class = error_class_for_status(response.status)
        message = error_message_for_status(response)
        raise error_class.new(message, status_code: response.status, response_body: response.body)
      end

      def error_class_for_status(status)
        case status
        when 401 then AuthenticationError
        when 429 then RateLimitError
        when 400..499 then InvalidRequestError
        else ApiError
        end
      end

      def error_message_for_status(response)
        case response.status
        when 401 then 'Invalid API key'
        when 429 then 'Rate limit exceeded'
        when 400..499 then "Request failed: #{response.body}"
        else "API error: #{response.body}"
        end
      end

      def normalize_images(images)
        return [] if images.nil? || images.empty?

        images.map { |img| ImageInput.from(img) }
      end

      def validate_image_count!(images, max:)
        return if images.nil? || images.length <= max

        raise InvalidRequestError.new(
          "Too many images: #{images.length} provided, maximum is #{max}",
          status_code: 400
        )
      end
    end
  end
end
