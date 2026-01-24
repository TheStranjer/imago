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
        raise_if_images_provided(opts)
        response = execute_generate_request(prompt, opts)
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

      def execute_generate_request(prompt, opts)
        conn = connection(BASE_URL)
        body = build_request_body(prompt, opts)
        conn.post('images/generations') { |req| configure_request(req, body) }
      end

      def configure_request(req, body)
        req.headers['Authorization'] = auth_header
        req.body = body
      end

      def auth_header
        "Bearer #{api_key}"
      end

      def build_request_body(prompt, opts)
        {
          model: model,
          prompt: prompt,
          n: opts[:n] || 1,
          response_format: opts[:response_format] || 'url'
        }.merge(opts.except(:n, :response_format))
      end

      def parse_generate_response(body)
        images = body['data']&.map { |img| { url: img['url'], base64: img['b64_json'] }.compact }
        { images: images || [], created: body['created'] }
      end

      def raise_if_images_provided(opts)
        return unless opts[:images] && !opts[:images].empty?

        raise UnsupportedFeatureError.new(
          'xAI does not currently support image inputs. ' \
          'Image-to-image generation may be available in future API versions.',
          provider: :xai,
          feature: :image_input
        )
      end
    end
  end
end
