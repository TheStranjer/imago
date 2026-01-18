# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago::Providers::XAI do
  let(:api_key) { 'test-xai-key' }
  let(:provider) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    it 'uses grok-2-image as default model' do
      expect(provider.model).to eq('grok-2-image')
    end

    it 'accepts custom model' do
      custom_provider = described_class.new(model: 'grok-2-image-1212', api_key: api_key)
      expect(custom_provider.model).to eq('grok-2-image-1212')
    end

    context 'with environment variable' do
      before do
        allow(ENV).to receive(:fetch).with('XAI_API_KEY', nil).and_return('env-xai-key')
      end

      it 'reads API key from XAI_API_KEY' do
        env_provider = described_class.new
        expect(env_provider.api_key).to eq('env-xai-key')
      end
    end
  end

  describe '#generate' do
    let(:success_response) do
      {
        created: 1_234_567_890,
        data: [
          { url: 'https://example.com/grok-image.png' }
        ]
      }
    end

    before do
      stub_request(:post, 'https://api.x.ai/v1/images/generations')
        .to_return(
          status: 200,
          body: success_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'sends a POST request to the images endpoint' do
      provider.generate('A robot')

      expect(WebMock).to have_requested(:post, 'https://api.x.ai/v1/images/generations')
        .with(headers: { 'Authorization' => 'Bearer test-xai-key' })
    end

    it 'includes the prompt in the request body' do
      provider.generate('A robot')

      expect(WebMock).to have_requested(:post, 'https://api.x.ai/v1/images/generations')
        .with(body: hash_including('prompt' => 'A robot'))
    end

    it 'includes the model in the request body' do
      provider.generate('A robot')

      expect(WebMock).to have_requested(:post, 'https://api.x.ai/v1/images/generations')
        .with(body: hash_including('model' => 'grok-2-image'))
    end

    it 'uses default options' do
      provider.generate('A robot')

      expect(WebMock).to have_requested(:post, 'https://api.x.ai/v1/images/generations')
        .with(body: hash_including(
          'n' => 1,
          'response_format' => 'url'
        ))
    end

    it 'allows overriding options' do
      provider.generate('A robot', n: 2, response_format: 'b64_json')

      expect(WebMock).to have_requested(:post, 'https://api.x.ai/v1/images/generations')
        .with(body: hash_including(
          'n' => 2,
          'response_format' => 'b64_json'
        ))
    end

    it 'returns parsed image data' do
      result = provider.generate('A robot')

      expect(result[:images]).to be_an(Array)
      expect(result[:images].length).to eq(1)
      expect(result[:images].first[:url]).to eq('https://example.com/grok-image.png')
      expect(result[:created]).to eq(1_234_567_890)
    end

    context 'with base64 response' do
      let(:base64_response) do
        {
          created: 1_234_567_890,
          data: [{ b64_json: 'xaibase64data' }]
        }
      end

      before do
        stub_request(:post, 'https://api.x.ai/v1/images/generations')
          .to_return(
            status: 200,
            body: base64_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns base64 data' do
        result = provider.generate('A robot', response_format: 'b64_json')
        expect(result[:images].first[:base64]).to eq('xaibase64data')
      end
    end

    context 'with API error' do
      before do
        stub_request(:post, 'https://api.x.ai/v1/images/generations')
          .to_return(status: 429, body: '{"error": "Rate limit exceeded"}')
      end

      it 'raises RateLimitError' do
        expect { provider.generate('A robot') }.to raise_error(Imago::RateLimitError)
      end
    end
  end

  describe '#models' do
    it 'returns hardcoded list of known models' do
      models = provider.models

      expect(models).to eq(described_class::KNOWN_IMAGE_MODELS)
      expect(models).to include('grok-2-image', 'grok-2-image-1212')
    end

    it 'does not make any API calls' do
      provider.models

      expect(WebMock).not_to have_requested(:get, /api.x.ai/)
    end
  end
end
