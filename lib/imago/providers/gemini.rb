# frozen_string_literal: true

module Imago
  module Providers
    class Gemini < Base
      BASE_URL = 'https://generativelanguage.googleapis.com/v1beta'
      MAX_IMAGES = 10

      KNOWN_IMAGE_MODELS = %w[
        imagen-3.0-generate-002
        imagen-3.0-generate-001
        gemini-2.0-flash-exp-image-generation
        gemini-2.5-flash-image
        gemini-3-pro-image-preview
      ].freeze

      def generate(prompt, opts = {})
        validate_image_count!(opts[:images], max: MAX_IMAGES)
        response = execute_generate_request(prompt, opts)
        response_parser.parse(handle_response(response))
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

      def response_parser
        @response_parser ||= Imago::GeminiResponseParser.new
      end

      def execute_generate_request(prompt, opts)
        conn = connection(BASE_URL)
        body = build_request_body(prompt, opts)
        conn.post(generate_endpoint) { |req| configure_request(req, body) }
      end

      def generate_endpoint
        "models/#{model}:generateContent"
      end

      def configure_request(req, body)
        req.params['key'] = api_key
        req.body = body
      end

      def build_request_body(prompt, opts)
        body = { contents: [{ parts: build_parts(prompt, opts) }] }
        body[:generationConfig] = build_generation_config(opts) if generation_config_present?(opts)
        body
      end

      def build_parts(prompt, opts)
        parts = [{ text: build_prompt(prompt, opts) }]
        normalize_images(opts[:images]).each { |img| parts << build_image_part(img) }
        parts
      end

      def build_image_part(image)
        image.url? ? build_file_data(image) : build_inline_data(image)
      end

      def build_file_data(image)
        { fileData: { fileUri: image.url, mimeType: image.mime_type }.compact }
      end

      def build_inline_data(image)
        { inlineData: { data: image.base64, mimeType: image.mime_type } }
      end

      def build_prompt(prompt, opts)
        opts[:negative_prompt] ? "#{prompt}. Avoid: #{opts[:negative_prompt]}" : prompt
      end

      def generation_config_present?(opts)
        opts[:n] || opts[:sample_count] || opts[:aspect_ratio] || opts[:seed]
      end

      def build_generation_config(opts)
        { candidateCount: opts[:sample_count] || opts[:n], seed: opts[:seed], aspectRatio: opts[:aspect_ratio] }.compact
      end

      def fetch_models
        response = connection(BASE_URL).get('models') { |req| req.params['key'] = api_key }
        filter_image_models(handle_response(response)['models'] || [])
      rescue ApiError
        KNOWN_IMAGE_MODELS
      end

      def filter_image_models(models)
        names = extract_image_model_names(models)
        names.empty? ? KNOWN_IMAGE_MODELS : names
      end

      def extract_image_model_names(models)
        content_models = models.select { |m| supports_generate_content?(m) }
        content_models.map { |m| m['name'].sub('models/', '') }.select { |n| image_model?(n) }
      end

      def supports_generate_content?(model)
        model['supportedGenerationMethods']&.include?('generateContent')
      end

      def image_model?(name)
        name.include?('imagen') || name.include?('image')
      end
    end
  end
end
