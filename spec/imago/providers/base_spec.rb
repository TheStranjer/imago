# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago::Providers::Base do
  let(:test_provider_class) do
    Class.new(described_class) do
      def default_model
        'test-model'
      end

      def env_key_name
        'TEST_API_KEY'
      end

      def generate(_prompt, _opts = {})
        { images: [] }
      end

      def models
        ['test-model']
      end
    end
  end

  describe '#initialize' do
    context 'with an API key' do
      it 'stores the API key' do
        provider = test_provider_class.new(api_key: 'my-key')
        expect(provider.api_key).to eq('my-key')
      end

      it 'uses the default model when none specified' do
        provider = test_provider_class.new(api_key: 'my-key')
        expect(provider.model).to eq('test-model')
      end

      it 'uses the specified model' do
        provider = test_provider_class.new(model: 'custom-model', api_key: 'my-key')
        expect(provider.model).to eq('custom-model')
      end
    end

    context 'with environment variable' do
      before do
        allow(ENV).to receive(:fetch).with('TEST_API_KEY', nil).and_return('env-key')
      end

      it 'reads API key from environment' do
        provider = test_provider_class.new
        expect(provider.api_key).to eq('env-key')
      end
    end

    context 'without API key' do
      before do
        allow(ENV).to receive(:fetch).with('TEST_API_KEY', nil).and_return(nil)
      end

      it 'raises ConfigurationError' do
        expect do
          test_provider_class.new
        end.to raise_error(Imago::ConfigurationError, /API key is required/)
      end
    end
  end

  describe '#generate' do
    it 'raises NotImplementedError on base class' do
      allow(ENV).to receive(:fetch).and_return('key')
      provider = described_class.allocate
      provider.instance_variable_set(:@api_key, 'key')
      provider.instance_variable_set(:@model, 'model')

      expect { provider.generate('test') }.to raise_error(NotImplementedError)
    end
  end

  describe '#models' do
    it 'raises NotImplementedError on base class' do
      allow(ENV).to receive(:fetch).and_return('key')
      provider = described_class.allocate
      provider.instance_variable_set(:@api_key, 'key')
      provider.instance_variable_set(:@model, 'model')

      expect { provider.models }.to raise_error(NotImplementedError)
    end
  end

  describe '#handle_response' do
    let(:provider) { test_provider_class.new(api_key: 'key') }

    it 'returns body for successful responses' do
      response = instance_double(Faraday::Response, status: 200, body: { 'data' => 'test' })
      result = provider.send(:handle_response, response)
      expect(result).to eq({ 'data' => 'test' })
    end

    it 'raises AuthenticationError for 401' do
      response = instance_double(Faraday::Response, status: 401, body: 'Unauthorized')
      expect do
        provider.send(:handle_response, response)
      end.to raise_error(Imago::AuthenticationError)
    end

    it 'raises RateLimitError for 429' do
      response = instance_double(Faraday::Response, status: 429, body: 'Too many requests')
      expect do
        provider.send(:handle_response, response)
      end.to raise_error(Imago::RateLimitError)
    end

    it 'raises InvalidRequestError for 4xx errors' do
      response = instance_double(Faraday::Response, status: 400, body: 'Bad request')
      expect do
        provider.send(:handle_response, response)
      end.to raise_error(Imago::InvalidRequestError)
    end

    it 'raises ApiError for 5xx errors' do
      response = instance_double(Faraday::Response, status: 500, body: 'Server error')
      expect do
        provider.send(:handle_response, response)
      end.to raise_error(Imago::ApiError)
    end
  end
end
