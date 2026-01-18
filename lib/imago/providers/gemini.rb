# frozen_string_literal: true

module Imago
  module Providers
    class Gemini < Base
      BASE_URL = 'https://generativelanguage.googleapis.com/v1beta'

      KNOWN_IMAGE_MODELS = %w[
        imagen-3.0-generate-002
        imagen-3.0-generate-001
        gemini-2.0-flash-exp-image-generation
        gemini-2.5-flash-image
        gemini-3-pro-image-preview
      ].freeze

      def generate(prompt, opts = {})
        conn = connection(BASE_URL)
        endpoint = "models/#{model}:generateContent"

        response = conn.post(endpoint) do |req|
          req.params['key'] = api_key
          req.body = build_request_body(prompt, opts)
        end

        parse_generate_response(handle_response(response))
      end

      def models
        @models ||= fetch_models
      end

      protected

      def default_model
        'gemini-3-pro-image-preview'
      end

      def env_key_name
        'GEMINI_API_KEY'
      end

      private

      def build_request_body(prompt, opts)
        body = { contents: [{ parts: [{ text: build_prompt(prompt, opts) }] }] }
        body[:generationConfig] = build_generation_config(opts) if generation_config_present?(opts)
        body
      end

      def build_prompt(prompt, opts)
        return prompt unless opts[:negative_prompt]

        "#{prompt}. Avoid: #{opts[:negative_prompt]}"
      end

      def generation_config_present?(opts)
        opts[:n] || opts[:sample_count] || opts[:aspect_ratio] || opts[:seed]
      end

      def build_generation_config(opts)
        config = {}
        config[:candidateCount] = opts[:sample_count] || opts[:n] if opts[:n] || opts[:sample_count]
        config[:seed] = opts[:seed] if opts[:seed]
        config[:aspectRatio] = opts[:aspect_ratio] if opts[:aspect_ratio]
        config
      end

      def parse_generate_response(body)
        candidates = body['candidates'] || []
        images = candidates.flat_map { |candidate| extract_images_from_candidate(candidate) }
        { images: images }
      end

      def extract_images_from_candidate(candidate)
        parts = candidate.dig('content', 'parts') || []
        parts.filter_map do |part|
          next unless part['inlineData']

          { base64: part['inlineData']['data'], mime_type: part['inlineData']['mimeType'] }.compact
        end
      end

      def fetch_models
        conn = connection(BASE_URL)
        response = conn.get('models') do |req|
          req.params['key'] = api_key
        end

        body = handle_response(response)
        filter_image_models(body['models'] || [])
      rescue ApiError
        KNOWN_IMAGE_MODELS
      end

      def filter_image_models(models)
        image_model_names = models
                            .select { |m| m['supportedGenerationMethods']&.include?('generateContent') }
                            .map { |m| m['name'].sub('models/', '') }
                            .select { |name| name.include?('imagen') || name.include?('image') }

        image_model_names.empty? ? KNOWN_IMAGE_MODELS : image_model_names
      end
    end
  end
end
