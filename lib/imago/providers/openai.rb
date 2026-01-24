# frozen_string_literal: true

require 'faraday/multipart'

module Imago
  module Providers
    class OpenAI < Base
      BASE_URL = 'https://api.openai.com/v1'
      MAX_IMAGES = 16

      KNOWN_IMAGE_MODELS = %w[dall-e-3 dall-e-2 gpt-image-1 gpt-image-1.5 gpt-image-1-mini].freeze
      MODELS_SUPPORTING_IMAGE_INPUT = %w[dall-e-2 gpt-image-1 gpt-image-1.5 gpt-image-1-mini].freeze

      def generate(prompt, opts = {})
        has_images = opts[:images] && !opts[:images].empty?
        has_images ? generate_with_images(prompt, opts) : generate_text_only(prompt, opts)
      end

      def models
        @models ||= fetch_models
      end

      protected

      def default_model
        'gpt-image-1.5'
      end

      def env_key_name
        'OPENAI_API_KEY'
      end

      private

      def generate_text_only(prompt, opts)
        response = post_with_auth('images/generations', build_request_body(prompt, opts))
        parse_response(response)
      end

      def generate_with_images(prompt, opts)
        validate_model_supports_images!
        validate_image_count!(opts[:images], max: MAX_IMAGES)
        response = post_multipart_edit(prompt, opts)
        parse_response(response)
      end

      def post_with_auth(endpoint, body)
        connection(BASE_URL).post(endpoint) do |req|
          req.headers['Authorization'] = auth_header
          req.body = body
        end
      end

      def post_multipart_edit(prompt, opts)
        body = build_multipart_body(prompt, opts)
        multipart_connection.post('images/edits') { |req| configure_auth_request(req, body) }
      end

      def build_multipart_body(prompt, opts)
        images = normalize_images(opts[:images])
        multipart_builder.build_body(prompt, images, opts)
      end

      def configure_auth_request(req, body)
        req.headers['Authorization'] = auth_header
        req.body = body
      end

      def parse_response(response)
        body = handle_response(response)
        images = body['data']&.map { |img| parse_image(img) }
        { images: images || [], created: body['created'] }
      end

      def auth_header
        "Bearer #{api_key}"
      end

      def multipart_builder
        @multipart_builder ||= Imago::MultipartBuilder.new(model)
      end

      def multipart_connection
        @multipart_connection ||= Faraday.new(url: BASE_URL) do |conn|
          conn.request :multipart
          conn.response :json
          conn.adapter Faraday.default_adapter
        end
      end

      def validate_model_supports_images!
        return if MODELS_SUPPORTING_IMAGE_INPUT.include?(model)

        raise InvalidRequestError.new(
          "Model '#{model}' does not support image inputs. Supported: #{MODELS_SUPPORTING_IMAGE_INPUT.join(', ')}",
          status_code: 400
        )
      end

      def build_request_body(prompt, opts)
        { model: model, prompt: prompt }.merge(opts)
      end

      def parse_image(img)
        { url: img['url'], base64: img['b64_json'], revised_prompt: img['revised_prompt'] }.compact
      end

      def fetch_models
        response = connection(BASE_URL).get('models') { |req| req.headers['Authorization'] = auth_header }
        filter_image_models(handle_response(response)['data'] || [])
      rescue ApiError
        KNOWN_IMAGE_MODELS
      end

      def filter_image_models(models)
        ids = models.map { |m| m['id'] }.select { |id| id.include?('dall-e') || id.include?('image') }
        ids.empty? ? KNOWN_IMAGE_MODELS : ids
      end
    end
  end
end
