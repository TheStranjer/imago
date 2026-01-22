# frozen_string_literal: true

module Imago
  class ImageInput
    MIME_TYPES = {
      'png' => 'image/png',
      'jpg' => 'image/jpeg',
      'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif'
    }.freeze

    attr_reader :url, :base64, :mime_type

    def self.from(input)
      case input
      when String
        from_url_string(input)
      when Hash
        from_hash(input)
      else
        raise ArgumentError, "Invalid image input: expected String or Hash, got #{input.class}"
      end
    end

    def self.from_url_string(url)
      mime_type = detect_mime_type(url)
      new(url: url, mime_type: mime_type)
    end

    def self.from_hash(hash)
      hash = hash.transform_keys(&:to_sym)

      if hash[:base64]
        raise ArgumentError, 'mime_type is required for base64 images' unless hash[:mime_type]

        new(base64: hash[:base64], mime_type: hash[:mime_type])
      elsif hash[:url]
        mime_type = hash[:mime_type] || detect_mime_type(hash[:url])
        new(url: hash[:url], mime_type: mime_type)
      else
        raise ArgumentError, 'Image hash must contain either :url or :base64 key'
      end
    end

    def self.detect_mime_type(url)
      extension = File.extname(URI.parse(url).path).delete('.').downcase
      MIME_TYPES[extension]
    rescue URI::InvalidURIError
      nil
    end

    private_class_method :from_url_string, :from_hash, :detect_mime_type

    def initialize(url: nil, base64: nil, mime_type: nil)
      @url = url
      @base64 = base64
      @mime_type = mime_type
    end

    def url?
      !@url.nil?
    end

    def base64?
      !@base64.nil?
    end
  end
end
