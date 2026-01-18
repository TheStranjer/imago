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
end
