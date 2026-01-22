# frozen_string_literal: true

require 'faraday/multipart'
require 'base64'

module Imago
  module Providers
    class OpenAI < Base
      BASE_URL = 'https://api.openai.com/v1'
      MAX_IMAGES = 16

      KNOWN_IMAGE_MODELS = %w[
        dall-e-3
        dall-e-2
        gpt-image-1
        gpt-image-1.5
        gpt-image-1-mini
      ].freeze

      MODELS_SUPPORTING_IMAGE_INPUT = %w[
        dall-e-2
        gpt-image-1
        gpt-image-1.5
        gpt-image-1-mini
      ].freeze

      def generate(prompt, opts = {})
        images = opts[:images]
        if images && !images.empty?
          generate_with_images(prompt, opts)
        else
          generate_text_only(prompt, opts)
        end
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
        conn = connection(BASE_URL)
        response = conn.post('images/generations') do |req|
          req.headers['Authorization'] = "Bearer #{api_key}"
          req.body = build_request_body(prompt, opts)
        end

        parse_generate_response(handle_response(response))
      end

      def generate_with_images(prompt, opts)
        validate_model_supports_images!
        validate_image_count!(opts[:images], max: MAX_IMAGES)

        images = normalize_images(opts[:images])
        conn = multipart_connection(BASE_URL)

        response = conn.post('images/edits') do |req|
          req.headers['Authorization'] = "Bearer #{api_key}"
          req.body = build_multipart_body(prompt, images, opts)
        end

        parse_generate_response(handle_response(response))
      end

      def validate_model_supports_images!
        return if MODELS_SUPPORTING_IMAGE_INPUT.include?(model)

        supported = MODELS_SUPPORTING_IMAGE_INPUT.join(', ')
        raise InvalidRequestError.new(
          "Model '#{model}' does not support image inputs. Supported models: #{supported}",
          status_code: 400
        )
      end

      def multipart_connection(base_url)
        Faraday.new(url: base_url) do |conn|
          conn.request :multipart
          conn.response :json
          conn.adapter Faraday.default_adapter
        end
      end

      def build_multipart_body(prompt, images, opts)
        body = {
          model: model,
          prompt: prompt
        }

        images.each_with_index do |image, index|
          body["image[#{index}]"] = build_image_part(image)
        end

        clean_opts = opts.except(:images)
        body.merge(clean_opts)
      end

      def build_image_part(image)
        if image.url?
          image.url
        else
          io = StringIO.new(Base64.decode64(image.base64))
          extension = image.mime_type&.split('/')&.last || 'png'
          Faraday::Multipart::FilePart.new(io, image.mime_type, "image.#{extension}")
        end
      end

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
