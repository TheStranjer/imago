# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago::Providers::Gemini do
  let(:api_key) { 'test-gemini-key' }
  let(:provider) { described_class.new(api_key: api_key) }
  let(:default_model) { 'gemini-3-pro-image-preview' }

  describe '#initialize' do
    it 'uses gemini-3-pro-image-preview as default model' do
      expect(provider.model).to eq(default_model)
    end

    it 'accepts custom model' do
      custom_provider = described_class.new(model: 'gemini-2.5-flash-image', api_key: api_key)
      expect(custom_provider.model).to eq('gemini-2.5-flash-image')
    end

    context 'with environment variable' do
      before do
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY', nil).and_return('env-gemini-key')
      end

      it 'reads API key from GEMINI_API_KEY' do
        env_provider = described_class.new
        expect(env_provider.api_key).to eq('env-gemini-key')
      end
    end
  end

  describe '#generate' do
    let(:success_response) do
      {
        candidates: [
          {
            content: {
              parts: [
                {
                  inlineData: {
                    mimeType: 'image/png',
                    data: 'base64imagedata'
                  }
                }
              ],
              role: 'model'
            },
            finishReason: 'STOP',
            index: 0
          }
        ],
        usageMetadata: {
          promptTokenCount: 25,
          totalTokenCount: 25
        }
      }
    end

    let(:expected_endpoint) do
      "https://generativelanguage.googleapis.com/v1beta/models/#{default_model}:generateContent"
    end

    before do
      stub_request(:post, expected_endpoint)
        .with(query: { 'key' => api_key })
        .to_return(
          status: 200,
          body: success_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'sends a POST request to the generateContent endpoint' do
      provider.generate('A sunset')

      expect(WebMock).to have_requested(:post, expected_endpoint)
        .with(query: { 'key' => 'test-gemini-key' })
    end

    it 'includes the prompt in the request body' do
      provider.generate('A sunset')

      expect(WebMock).to have_requested(:post, expected_endpoint)
        .with(query: { 'key' => api_key },
              body: hash_including('contents' => [{ 'parts' => [{ 'text' => 'A sunset' }] }]))
    end

    it 'does not include generationConfig when no options provided' do
      provider.generate('A sunset')

      expect(WebMock).to have_requested(:post, expected_endpoint)
        .with(query: { 'key' => api_key }) do |req|
          body = JSON.parse(req.body)
          !body.key?('generationConfig')
        end
    end

    it 'allows overriding candidate count' do
      provider.generate('A sunset', n: 3)

      expect(WebMock).to have_requested(:post, expected_endpoint)
        .with(query: { 'key' => api_key },
              body: hash_including('generationConfig' => hash_including('candidateCount' => 3)))
    end

    it 'supports aspect ratio option' do
      provider.generate('A sunset', aspect_ratio: '16:9')

      expect(WebMock).to have_requested(:post, expected_endpoint)
        .with(query: { 'key' => api_key },
              body: hash_including('generationConfig' => hash_including('aspectRatio' => '16:9')))
    end

    it 'supports negative prompt option by appending to prompt' do
      provider.generate('A sunset', negative_prompt: 'clouds')

      expect(WebMock).to have_requested(:post, expected_endpoint)
        .with(query: { 'key' => api_key },
              body: hash_including('contents' => [{ 'parts' => [{ 'text' => 'A sunset. Avoid: clouds' }] }]))
    end

    it 'supports seed option' do
      provider.generate('A sunset', seed: 12_345)

      expect(WebMock).to have_requested(:post, expected_endpoint)
        .with(query: { 'key' => api_key },
              body: hash_including('generationConfig' => hash_including('seed' => 12_345)))
    end

    it 'returns parsed image data' do
      result = provider.generate('A sunset')

      expect(result[:images]).to be_an(Array)
      expect(result[:images].length).to eq(1)
      expect(result[:images].first[:base64]).to eq('base64imagedata')
      expect(result[:images].first[:mime_type]).to eq('image/png')
    end

    context 'with multiple images in response' do
      before do
        multi_image_response = {
          candidates: [
            {
              content: {
                parts: [
                  { inlineData: { mimeType: 'image/png', data: 'image1data' } },
                  { inlineData: { mimeType: 'image/png', data: 'image2data' } }
                ]
              }
            }
          ]
        }
        stub_request(:post, expected_endpoint)
          .with(query: { 'key' => api_key })
          .to_return(
            status: 200,
            body: multi_image_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'extracts all images from response' do
        result = provider.generate('Multiple images')

        expect(result[:images].length).to eq(2)
        expect(result[:images][0][:base64]).to eq('image1data')
        expect(result[:images][1][:base64]).to eq('image2data')
      end
    end

    context 'with API error' do
      before do
        stub_request(:post, expected_endpoint)
          .with(query: { 'key' => api_key })
          .to_return(status: 401, body: '{"error": "Invalid API key"}')
      end

      it 'raises AuthenticationError' do
        expect { provider.generate('A sunset') }.to raise_error(Imago::AuthenticationError)
      end
    end
  end

  describe '#models' do
    context 'when API returns models' do
      before do
        stub_request(:get, 'https://generativelanguage.googleapis.com/v1beta/models')
          .with(query: { 'key' => api_key })
          .to_return(
            status: 200,
            body: {
              models: [
                {
                  name: 'models/gemini-2.5-flash-image',
                  supportedGenerationMethods: ['generateContent']
                },
                {
                  name: 'models/gemini-3-pro-image-preview',
                  supportedGenerationMethods: ['generateContent']
                },
                {
                  name: 'models/gemini-pro',
                  supportedGenerationMethods: ['generateContent']
                }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'fetches models from the API' do
        models = provider.models

        expect(WebMock).to have_requested(:get, 'https://generativelanguage.googleapis.com/v1beta/models')
          .with(query: { 'key' => 'test-gemini-key' })
        expect(models).to include('gemini-2.5-flash-image', 'gemini-3-pro-image-preview')
        expect(models).not_to include('gemini-pro')
      end

      it 'memoizes the result' do
        provider.models
        provider.models

        expect(WebMock).to have_requested(:get, 'https://generativelanguage.googleapis.com/v1beta/models')
          .with(query: { 'key' => api_key }).once
      end
    end

    context 'when API fails' do
      before do
        stub_request(:get, 'https://generativelanguage.googleapis.com/v1beta/models')
          .with(query: { 'key' => api_key })
          .to_return(status: 500, body: 'Internal server error')
      end

      it 'falls back to known models' do
        models = provider.models
        expect(models).to eq(described_class::KNOWN_IMAGE_MODELS)
      end
    end

    context 'when no image models found' do
      before do
        stub_request(:get, 'https://generativelanguage.googleapis.com/v1beta/models')
          .with(query: { 'key' => api_key })
          .to_return(
            status: 200,
            body: {
              models: [
                { name: 'models/gemini-pro', supportedGenerationMethods: ['generateContent'] }
              ]
            }.to_json,
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
