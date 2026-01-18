# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago::Client do
  let(:api_key) { 'test-api-key' }

  describe '#initialize' do
    context 'with a valid provider' do
      it 'creates an OpenAI provider' do
        client = described_class.new(provider: :openai, api_key: api_key)
        expect(client.provider).to be_a(Imago::Providers::OpenAI)
      end

      it 'creates a Gemini provider' do
        client = described_class.new(provider: :gemini, api_key: api_key)
        expect(client.provider).to be_a(Imago::Providers::Gemini)
      end

      it 'creates an xAI provider' do
        client = described_class.new(provider: :xai, api_key: api_key)
        expect(client.provider).to be_a(Imago::Providers::XAI)
      end

      it 'accepts string provider names' do
        client = described_class.new(provider: 'openai', api_key: api_key)
        expect(client.provider).to be_a(Imago::Providers::OpenAI)
      end

      it 'passes the model to the provider' do
        client = described_class.new(provider: :openai, model: 'dall-e-2', api_key: api_key)
        expect(client.model).to eq('dall-e-2')
      end
    end

    context 'with an invalid provider' do
      it 'raises ProviderNotFoundError' do
        expect do
          described_class.new(provider: :unknown, api_key: api_key)
        end.to raise_error(Imago::ProviderNotFoundError, /Unknown provider: unknown/)
      end
    end
  end

  describe '#generate' do
    let(:client) { described_class.new(provider: :openai, api_key: api_key) }

    before do
      stub_request(:post, 'https://api.openai.com/v1/images/generations')
        .to_return(
          status: 200,
          body: {
            created: 1_234_567_890,
            data: [{ url: 'https://example.com/image.png', revised_prompt: 'A cat' }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'delegates to the provider' do
      result = client.generate('A cat')
      expect(result[:images]).to be_an(Array)
      expect(result[:images].first[:url]).to eq('https://example.com/image.png')
    end

    it 'passes options to the provider' do
      client.generate('A cat', size: '512x512')

      expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/images/generations')
        .with(body: hash_including('size' => '512x512'))
    end
  end

  describe '#models' do
    let(:client) { described_class.new(provider: :openai, api_key: api_key) }

    before do
      stub_request(:get, 'https://api.openai.com/v1/models')
        .to_return(
          status: 200,
          body: {
            data: [
              { id: 'dall-e-3', object: 'model' },
              { id: 'dall-e-2', object: 'model' },
              { id: 'gpt-4', object: 'model' }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'delegates to the provider' do
      result = client.models
      expect(result).to include('dall-e-3')
      expect(result).to include('dall-e-2')
    end
  end
end
