# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago do
  it 'has a version number' do
    expect(Imago::VERSION).not_to be_nil
  end

  describe '.new' do
    let(:api_key) { 'test-api-key' }

    it 'creates a new Client instance' do
      client = described_class.new(provider: :openai, api_key: api_key)
      expect(client).to be_a(Imago::Client)
    end

    it 'passes options to Client' do
      client = described_class.new(provider: :openai, model: 'dall-e-2', api_key: api_key)
      expect(client.model).to eq('dall-e-2')
    end
  end
end
