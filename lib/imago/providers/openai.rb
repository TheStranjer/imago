# frozen_string_literal: true

module Imago
  module Providers
    class OpenAI < Base
      BASE_URL = 'https://api.openai.com/v1'

      KNOWN_IMAGE_MODELS = %w[
        dall-e-3
        dall-e-2
        gpt-image-1
        gpt-image-1.5
        gpt-image-1-mini
      ].freeze

      def generate(prompt, opts = {})
        conn = connection(BASE_URL)
        response = conn.post('images/generations') do |req|
          req.headers['Authorization'] = "Bearer #{api_key}"
          req.body = build_request_body(prompt, opts)
        end

        parse_generate_response(handle_response(response))
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

      def build_request_body(prompt, opts)
        {
          model: model,
          prompt: prompt
        }.merge(opts)
      end

      def parse_generate_response(body)
        images = body['data']&.map { |img| parse_image(img) }
        { images: images || [], created: body['created'] }
      end

      def parse_image(img)
        { url: img['url'], base64: img['b64_json'], revised_prompt: img['revised_prompt'] }.compact
      end

      def fetch_models
        conn = connection(BASE_URL)
        response = conn.get('models') do |req|
          req.headers['Authorization'] = "Bearer #{api_key}"
        end

        body = handle_response(response)
        filter_image_models(body['data'] || [])
      rescue ApiError
        KNOWN_IMAGE_MODELS
      end

      def filter_image_models(models)
        image_model_ids = models
                          .map { |m| m['id'] }
                          .select { |id| id.include?('dall-e') || id.include?('image') }

        image_model_ids.empty? ? KNOWN_IMAGE_MODELS : image_model_ids
      end
    end
  end
end
