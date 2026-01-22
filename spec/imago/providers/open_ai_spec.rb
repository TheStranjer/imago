# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago::Providers::OpenAI do
  let(:api_key) { 'test-openai-key' }
  let(:provider) { described_class.new(api_key: api_key) }
  let(:default_model) { 'gpt-image-1.5' }

  describe '#initialize' do
    it 'uses gpt-image-1.5 as default model' do
      expect(provider.model).to eq(default_model)
    end

    it 'accepts custom model' do
      custom_provider = described_class.new(model: 'dall-e-2', api_key: api_key)
      expect(custom_provider.model).to eq('dall-e-2')
    end

    context 'with environment variable' do
      before do
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('env-openai-key')
      end

      it 'reads API key from OPENAI_API_KEY' do
        env_provider = described_class.new
        expect(env_provider.api_key).to eq('env-openai-key')
      end
    end
  end

  describe '#generate' do
    let(:success_response) do
      {
        created: 1_234_567_890,
        data: [
          {
            url: 'https://example.com/image1.png',
            revised_prompt: 'A fluffy cat sitting'
          }
        ]
      }
    end

    before do
      stub_request(:post, 'https://api.openai.com/v1/images/generations')
        .to_return(
          status: 200,
          body: success_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'sends a POST request to the images endpoint' do
      provider.generate('A cat')

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        .with(headers: { 'Authorization' => 'Bearer test-openai-key' })
    end

    it 'includes the prompt in the request body' do
      provider.generate('A cat')

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        .with(body: hash_including('prompt' => 'A cat'))
    end

    it 'includes the model in the request body' do
      provider.generate('A cat')

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        .with(body: hash_including('model' => default_model))
    end

    it 'sends only model and prompt by default' do
      provider.generate('A cat')

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        .with(body: { 'model' => default_model, 'prompt' => 'A cat' })
    end

    it 'allows overriding options' do
      provider.generate('A cat', n: 2, size: '512x512', quality: 'hd')

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        .with(body: hash_including(
          'n' => 2,
          'size' => '512x512',
          'quality' => 'hd'
        ))
    end

    it 'returns parsed image data' do
      result = provider.generate('A cat')

      expect(result[:images]).to be_an(Array)
      expect(result[:images].length).to eq(1)
      expect(result[:images].first[:url]).to eq('https://example.com/image1.png')
      expect(result[:images].first[:revised_prompt]).to eq('A fluffy cat sitting')
      expect(result[:created]).to eq(1_234_567_890)
    end

    context 'with base64 response' do
      let(:base64_response) do
        {
          created: 1_234_567_890,
          data: [{ b64_json: 'base64encodeddata' }]
        }
      end

      before do
        stub_request(:post, 'https://api.openai.com/v1/images/generations')
          .to_return(
            status: 200,
            body: base64_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns base64 data' do
        result = provider.generate('A cat', response_format: 'b64_json')
        expect(result[:images].first[:base64]).to eq('base64encodeddata')
      end
    end

    context 'with API error' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/images/generations')
          .to_return(status: 401, body: '{"error": "Invalid API key"}')
      end

      it 'raises AuthenticationError' do
        expect { provider.generate('A cat') }.to raise_error(Imago::AuthenticationError)
      end
    end
  end

  describe '#models' do
    context 'when API returns models' do
      before do
        stub_request(:get, 'https://api.openai.com/v1/models')
          .to_return(
            status: 200,
            body: {
              data: [
                { id: 'dall-e-3', object: 'model' },
                { id: 'dall-e-2', object: 'model' },
                { id: 'gpt-4', object: 'model' },
                { id: 'gpt-image-1', object: 'model' }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'fetches models from the API' do
        models = provider.models

        expect(WebMock).to have_requested(:get, 'https://api.openai.com/v1/models')
          .with(headers: { 'Authorization' => 'Bearer test-openai-key' })
        expect(models).to include('dall-e-3', 'dall-e-2', 'gpt-image-1')
        expect(models).not_to include('gpt-4')
      end

      it 'memoizes the result' do
        provider.models
        provider.models

        expect(WebMock).to have_requested(:get, 'https://api.openai.com/v1/models').once
      end
    end

    context 'when API fails' do
      before do
        stub_request(:get, 'https://api.openai.com/v1/models')
          .to_return(status: 500, body: 'Internal server error')
      end

      it 'falls back to known models' do
        models = provider.models
        expect(models).to eq(described_class::KNOWN_IMAGE_MODELS)
      end
    end

    context 'when no image models found' do
      before do
        stub_request(:get, 'https://api.openai.com/v1/models')
          .to_return(
            status: 200,
            body: { data: [{ id: 'gpt-4', object: 'model' }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'falls back to known models' do
        models = provider.models
        expect(models).to eq(described_class::KNOWN_IMAGE_MODELS)
      end
    end
  end

  describe 'image input support' do
    let(:edit_success_response) do
      {
        created: 1_234_567_890,
        data: [{ url: 'https://example.com/edited.png' }]
      }
    end

    context 'with gpt-image-1.5 (default model)' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/images/edits')
          .to_return(
            status: 200,
            body: edit_success_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'POSTs to /images/edits endpoint' do
        provider.generate('Make this colorful', images: ['https://example.com/photo.jpg'])

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/edits')
          .with(headers: { 'Authorization' => 'Bearer test-openai-key' })
      end

      it 'sends multipart form data with URL images' do
        provider.generate('Edit this', images: ['https://example.com/photo.jpg'])

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/edits') do |req|
          expect(req.body).to include('image[0]')
          expect(req.body).to include('https://example.com/photo.jpg')
          expect(req.body).to include('prompt')
          expect(req.body).to include('Edit this')
        end
      end

      it 'sends multipart form data with base64 images' do
        # Small valid base64 PNG data
        base64_data = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='

        provider.generate('Add a hat', images: [{ base64: base64_data, mime_type: 'image/png' }])

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/edits') do |req|
          expect(req.headers['Content-Type']).to include('multipart/form-data')
        end
      end

      it 'handles multiple images' do
        provider.generate('Combine', images: [
                            'https://example.com/photo1.jpg',
                            'https://example.com/photo2.jpg'
                          ])

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/edits') do |req|
          expect(req.body).to include('image[0]')
          expect(req.body).to include('image[1]')
        end
      end

      it 'returns parsed response' do
        result = provider.generate('Edit', images: ['https://example.com/photo.jpg'])

        expect(result[:images]).to be_an(Array)
        expect(result[:images].first[:url]).to eq('https://example.com/edited.png')
      end
    end

    context 'with dall-e-2' do
      let(:dalle2_provider) { described_class.new(model: 'dall-e-2', api_key: api_key) }

      before do
        stub_request(:post, 'https://api.openai.com/v1/images/edits')
          .to_return(
            status: 200,
            body: edit_success_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'supports image inputs' do
        expect do
          dalle2_provider.generate('Edit', images: ['https://example.com/photo.jpg'])
        end.not_to raise_error
      end
    end

    context 'with dall-e-3' do
      let(:dalle3_provider) { described_class.new(model: 'dall-e-3', api_key: api_key) }

      it 'raises InvalidRequestError' do
        expect do
          dalle3_provider.generate('Edit', images: ['https://example.com/photo.jpg'])
        end.to raise_error(Imago::InvalidRequestError, /dall-e-3.*does not support image inputs/)
      end
    end

    context 'with too many images' do
      it 'raises InvalidRequestError when exceeding 16 images' do
        images = (1..17).map { |i| "https://example.com/photo#{i}.jpg" }

        expect do
          provider.generate('Edit', images: images)
        end.to raise_error(Imago::InvalidRequestError, /Too many images: 17 provided, maximum is 16/)
      end

      it 'allows exactly 16 images' do
        stub_request(:post, 'https://api.openai.com/v1/images/edits')
          .to_return(
            status: 200,
            body: edit_success_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        images = (1..16).map { |i| "https://example.com/photo#{i}.jpg" }

        expect { provider.generate('Edit', images: images) }.not_to raise_error
      end
    end

    context 'without images' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/images/generations')
          .to_return(
            status: 200,
            body: { created: 123, data: [{ url: 'https://example.com/img.png' }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'uses /images/generations endpoint' do
        provider.generate('A cat')

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/images/edits')
      end

      it 'works with empty images array' do
        provider.generate('A cat', images: [])

        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
      end
    end

    context 'with mixed image formats' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/images/edits')
          .to_return(
            status: 200,
            body: edit_success_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'handles URL string and base64 hash together' do
        base64_data = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='

        expect do
          provider.generate('Combine', images: [
                              'https://example.com/photo.jpg',
                              { base64: base64_data, mime_type: 'image/png' }
                            ])
        end.not_to raise_error
      end
    end
  end
end
