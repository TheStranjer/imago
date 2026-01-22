# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago::ImageInput do
  describe '.from' do
    context 'with URL string' do
      it 'creates a URL type input' do
        input = described_class.from('https://example.com/photo.jpg')

        expect(input).to be_url
        expect(input).not_to be_base64
        expect(input.url).to eq('https://example.com/photo.jpg')
      end

      it 'auto-detects mime type from jpg extension' do
        input = described_class.from('https://example.com/photo.jpg')
        expect(input.mime_type).to eq('image/jpeg')
      end

      it 'auto-detects mime type from jpeg extension' do
        input = described_class.from('https://example.com/photo.jpeg')
        expect(input.mime_type).to eq('image/jpeg')
      end

      it 'auto-detects mime type from png extension' do
        input = described_class.from('https://example.com/photo.png')
        expect(input.mime_type).to eq('image/png')
      end

      it 'auto-detects mime type from webp extension' do
        input = described_class.from('https://example.com/photo.webp')
        expect(input.mime_type).to eq('image/webp')
      end

      it 'auto-detects mime type from gif extension' do
        input = described_class.from('https://example.com/photo.gif')
        expect(input.mime_type).to eq('image/gif')
      end

      it 'returns nil mime_type for unknown extension' do
        input = described_class.from('https://example.com/photo.unknown')
        expect(input.mime_type).to be_nil
      end

      it 'returns nil mime_type for URL without extension' do
        input = described_class.from('https://example.com/photo')
        expect(input.mime_type).to be_nil
      end
    end

    context 'with URL hash' do
      it 'creates a URL type input with explicit mime type' do
        input = described_class.from({ url: 'https://example.com/photo', mime_type: 'image/jpeg' })

        expect(input).to be_url
        expect(input.url).to eq('https://example.com/photo')
        expect(input.mime_type).to eq('image/jpeg')
      end

      it 'auto-detects mime type if not provided' do
        input = described_class.from({ url: 'https://example.com/photo.png' })

        expect(input.mime_type).to eq('image/png')
      end

      it 'uses explicit mime type over auto-detected' do
        input = described_class.from({ url: 'https://example.com/photo.png', mime_type: 'image/jpeg' })

        expect(input.mime_type).to eq('image/jpeg')
      end

      it 'works with string keys' do
        input = described_class.from({ 'url' => 'https://example.com/photo.jpg', 'mime_type' => 'image/png' })

        expect(input.url).to eq('https://example.com/photo.jpg')
        expect(input.mime_type).to eq('image/png')
      end
    end

    context 'with base64 hash' do
      it 'creates a base64 type input' do
        input = described_class.from({ base64: 'iVBORw0KGgo...', mime_type: 'image/png' })

        expect(input).to be_base64
        expect(input).not_to be_url
        expect(input.base64).to eq('iVBORw0KGgo...')
        expect(input.mime_type).to eq('image/png')
      end

      it 'raises ArgumentError without mime_type' do
        expect do
          described_class.from({ base64: 'iVBORw0KGgo...' })
        end.to raise_error(ArgumentError, 'mime_type is required for base64 images')
      end

      it 'works with string keys' do
        input = described_class.from({ 'base64' => 'iVBORw0KGgo...', 'mime_type' => 'image/jpeg' })

        expect(input.base64).to eq('iVBORw0KGgo...')
        expect(input.mime_type).to eq('image/jpeg')
      end
    end

    context 'with invalid input' do
      it 'raises ArgumentError for non-String/Hash input' do
        expect do
          described_class.from(123)
        end.to raise_error(ArgumentError, /Invalid image input: expected String or Hash, got Integer/)
      end

      it 'raises ArgumentError for array input' do
        expect do
          described_class.from(['https://example.com/photo.jpg'])
        end.to raise_error(ArgumentError, /Invalid image input: expected String or Hash, got Array/)
      end

      it 'raises ArgumentError for hash without url or base64' do
        expect do
          described_class.from({ mime_type: 'image/png' })
        end.to raise_error(ArgumentError, 'Image hash must contain either :url or :base64 key')
      end
    end
  end

  describe '#url?' do
    it 'returns true for URL input' do
      input = described_class.from('https://example.com/photo.jpg')
      expect(input.url?).to be true
    end

    it 'returns false for base64 input' do
      input = described_class.from({ base64: 'data', mime_type: 'image/png' })
      expect(input.url?).to be false
    end
  end

  describe '#base64?' do
    it 'returns true for base64 input' do
      input = described_class.from({ base64: 'data', mime_type: 'image/png' })
      expect(input.base64?).to be true
    end

    it 'returns false for URL input' do
      input = described_class.from('https://example.com/photo.jpg')
      expect(input.base64?).to be false
    end
  end
end
