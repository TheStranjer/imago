# frozen_string_literal: true

module Imago
  module Providers
    class XAI < Base
      BASE_URL = 'https://api.x.ai/v1'

      KNOWN_IMAGE_MODELS = %w[
        grok-2-image
        grok-2-image-1212
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
        KNOWN_IMAGE_MODELS
      end

      protected

      def default_model
        'grok-2-image'
      end

      def env_key_name
        'XAI_API_KEY'
      end

      private

      def build_request_body(prompt, opts)
        {
          model: model,
          prompt: prompt,
          n: opts[:n] || 1,
          response_format: opts[:response_format] || 'url'
        }.merge(opts.except(:n, :response_format))
      end

      def parse_generate_response(body)
        images = body['data']&.map do |img|
          {
            url: img['url'],
            base64: img['b64_json']
          }.compact
        end

        {
          images: images || [],
          created: body['created']
        }
      end
    end
  end
end
