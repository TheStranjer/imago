# frozen_string_literal: true

module Imago
  class GeminiResponseParser
    def parse(body)
      candidates = body['candidates'] || []
      images = candidates.flat_map { |candidate| extract_images(candidate) }
      { images: images }
    end

    private

    def extract_images(candidate)
      parts = candidate.dig('content', 'parts') || []
      parts.filter_map { |part| parse_image_part(part) }
    end

    def parse_image_part(part)
      return unless part['inlineData']

      { base64: part['inlineData']['data'], mime_type: part['inlineData']['mimeType'] }.compact
    end
  end
end
