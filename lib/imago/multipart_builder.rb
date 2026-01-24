# frozen_string_literal: true

require 'base64'

module Imago
  class MultipartBuilder
    def initialize(model)
      @model = model
    end

    def build_body(prompt, images, opts)
      body = base_body(prompt)
      add_images(body, images)
      body.merge(opts.except(:images))
    end

    def build_image_part(image)
      image.url? ? image.url : build_file_part(image)
    end

    private

    def base_body(prompt)
      { model: @model, prompt: prompt }
    end

    def add_images(body, images)
      images.each_with_index do |image, index|
        body["image[#{index}]"] = build_image_part(image)
      end
    end

    def build_file_part(image)
      io = StringIO.new(Base64.decode64(image.base64))
      extension = extract_extension(image.mime_type)
      Faraday::Multipart::FilePart.new(io, image.mime_type, "image.#{extension}")
    end

    def extract_extension(mime_type)
      mime_type&.split('/')&.last || 'png'
    end
  end
end
