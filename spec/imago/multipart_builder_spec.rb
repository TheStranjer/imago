# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago::MultipartBuilder do
  let(:model) { 'gpt-image-1' }
  let(:builder) { described_class.new(model) }

  describe '#initialize' do
    it 'stores the model' do
      expect(builder.instance_variable_get(:@model)).to eq(model)
    end
  end

  describe '#build_body' do
    let(:prompt) { 'Generate an image' }

    context 'without images' do
      it 'returns base body with model and prompt' do
        result = builder.build_body(prompt, [], {})

        expect(result[:model]).to eq(model)
        expect(result[:prompt]).to eq(prompt)
      end
    end

    context 'with URL images' do
      let(:image) { Imago::ImageInput.from('https://example.com/photo.jpg') }

      it 'includes image URLs in the body' do
        result = builder.build_body(prompt, [image], {})

        expect(result['image[0]']).to eq('https://example.com/photo.jpg')
      end
    end

    context 'with base64 images' do
      let(:image) { Imago::ImageInput.from(base64: 'iVBORw0KGgo...', mime_type: 'image/png') }

      it 'creates FilePart for base64 images' do
        result = builder.build_body(prompt, [image], {})

        expect(result['image[0]']).to be_a(Faraday::Multipart::FilePart)
      end
    end

    context 'with multiple images' do
      let(:images) do
        [
          Imago::ImageInput.from('https://example.com/photo1.jpg'),
          Imago::ImageInput.from('https://example.com/photo2.jpg')
        ]
      end

      it 'includes all images with indexed keys' do
        result = builder.build_body(prompt, images, {})

        expect(result['image[0]']).to eq('https://example.com/photo1.jpg')
        expect(result['image[1]']).to eq('https://example.com/photo2.jpg')
      end
    end

    context 'with additional options' do
      it 'merges options into the body' do
        result = builder.build_body(prompt, [], { size: '1024x1024', quality: 'hd' })

        expect(result[:size]).to eq('1024x1024')
        expect(result[:quality]).to eq('hd')
      end

      it 'excludes :images key from options' do
        result = builder.build_body(prompt, [], { size: '1024x1024', images: ['ignored'] })

        expect(result).not_to have_key(:images)
        expect(result[:size]).to eq('1024x1024')
      end
    end
  end

  describe '#build_image_part' do
    context 'with URL image' do
      let(:image) { Imago::ImageInput.from('https://example.com/photo.jpg') }

      it 'returns the URL string' do
        result = builder.build_image_part(image)

        expect(result).to eq('https://example.com/photo.jpg')
      end
    end

    context 'with base64 image' do
      let(:base64_data) { Base64.strict_encode64('fake image data') }
      let(:image) { Imago::ImageInput.from(base64: base64_data, mime_type: 'image/png') }

      it 'returns a Faraday FilePart' do
        result = builder.build_image_part(image)

        expect(result).to be_a(Faraday::Multipart::FilePart)
        expect(result.content_type).to eq('image/png')
      end

      it 'uses correct filename extension from mime_type' do
        result = builder.build_image_part(image)

        expect(result.original_filename).to eq('image.png')
      end
    end

    context 'with base64 image without mime_type' do
      let(:base64_data) { Base64.strict_encode64('fake image data') }

      it 'defaults to png extension' do
        image = instance_double(Imago::ImageInput, url?: false, base64: base64_data, mime_type: nil)
        result = builder.build_image_part(image)

        expect(result.original_filename).to eq('image.png')
      end
    end
  end
end
