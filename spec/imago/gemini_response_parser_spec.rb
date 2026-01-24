# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Imago::GeminiResponseParser do
  let(:parser) { described_class.new }

  describe '#parse' do
    context 'with a valid response containing images' do
      let(:response_body) do
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  {
                    'inlineData' => {
                      'mimeType' => 'image/png',
                      'data' => 'base64imagedata'
                    }
                  }
                ],
                'role' => 'model'
              },
              'finishReason' => 'STOP'
            }
          ]
        }
      end

      it 'returns hash with images array' do
        result = parser.parse(response_body)

        expect(result).to be_a(Hash)
        expect(result[:images]).to be_an(Array)
      end

      it 'extracts base64 data from image' do
        result = parser.parse(response_body)

        expect(result[:images].first[:base64]).to eq('base64imagedata')
      end

      it 'extracts mime_type from image' do
        result = parser.parse(response_body)

        expect(result[:images].first[:mime_type]).to eq('image/png')
      end
    end

    context 'with multiple images in one candidate' do
      let(:response_body) do
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'inlineData' => { 'mimeType' => 'image/png', 'data' => 'image1' } },
                  { 'inlineData' => { 'mimeType' => 'image/jpeg', 'data' => 'image2' } }
                ]
              }
            }
          ]
        }
      end

      it 'extracts all images' do
        result = parser.parse(response_body)

        expect(result[:images].length).to eq(2)
        expect(result[:images][0][:base64]).to eq('image1')
        expect(result[:images][1][:base64]).to eq('image2')
      end
    end

    context 'with multiple candidates' do
      let(:response_body) do
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [{ 'inlineData' => { 'mimeType' => 'image/png', 'data' => 'candidate1' } }]
              }
            },
            {
              'content' => {
                'parts' => [{ 'inlineData' => { 'mimeType' => 'image/png', 'data' => 'candidate2' } }]
              }
            }
          ]
        }
      end

      it 'extracts images from all candidates' do
        result = parser.parse(response_body)

        expect(result[:images].length).to eq(2)
        expect(result[:images].map { |i| i[:base64] }).to contain_exactly('candidate1', 'candidate2')
      end
    end

    context 'with text-only parts' do
      let(:response_body) do
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => 'Some text response' }
                ]
              }
            }
          ]
        }
      end

      it 'returns empty images array' do
        result = parser.parse(response_body)

        expect(result[:images]).to eq([])
      end
    end

    context 'with mixed parts (text and images)' do
      let(:response_body) do
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => 'Here is your image' },
                  { 'inlineData' => { 'mimeType' => 'image/png', 'data' => 'imagedata' } }
                ]
              }
            }
          ]
        }
      end

      it 'only extracts image parts' do
        result = parser.parse(response_body)

        expect(result[:images].length).to eq(1)
        expect(result[:images].first[:base64]).to eq('imagedata')
      end
    end

    context 'with empty candidates' do
      let(:response_body) { { 'candidates' => [] } }

      it 'returns empty images array' do
        result = parser.parse(response_body)

        expect(result[:images]).to eq([])
      end
    end

    context 'with missing candidates key' do
      let(:response_body) { {} }

      it 'returns empty images array' do
        result = parser.parse(response_body)

        expect(result[:images]).to eq([])
      end
    end

    context 'with candidate missing content' do
      let(:response_body) do
        {
          'candidates' => [{ 'finishReason' => 'STOP' }]
        }
      end

      it 'returns empty images array' do
        result = parser.parse(response_body)

        expect(result[:images]).to eq([])
      end
    end

    context 'with candidate missing parts' do
      let(:response_body) do
        {
          'candidates' => [
            { 'content' => { 'role' => 'model' } }
          ]
        }
      end

      it 'returns empty images array' do
        result = parser.parse(response_body)

        expect(result[:images]).to eq([])
      end
    end

    context 'with nil mimeType' do
      let(:response_body) do
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'inlineData' => { 'data' => 'imagedata' } }
                ]
              }
            }
          ]
        }
      end

      it 'handles missing mimeType gracefully' do
        result = parser.parse(response_body)

        expect(result[:images].first[:base64]).to eq('imagedata')
        expect(result[:images].first).not_to have_key(:mime_type)
      end
    end
  end
end
