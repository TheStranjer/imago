# Imago

A unified Ruby interface for multiple image generation AI providers. Generate images using OpenAI (DALL-E), Google Gemini (Imagen), and xAI (Grok) through a single, consistent API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'imago'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install imago
```

## Configuration

Set API keys via environment variables:

```bash
export OPENAI_API_KEY="your-openai-key"
export GEMINI_API_KEY="your-gemini-key"
export XAI_API_KEY="your-xai-key"
```

Or pass them directly when creating a client.

## Usage

### Basic Usage

```ruby
require 'imago'

# Create a client for OpenAI
client = Imago.new(provider: :openai)

# Generate an image
result = client.generate("A serene mountain landscape at sunset")
puts result[:images].first[:url]
```

### Specifying a Model

```ruby
# Use a specific model
client = Imago.new(provider: :openai, model: 'dall-e-2')

result = client.generate("A cat wearing a hat")
```

### Passing API Key Directly

```ruby
client = Imago.new(
  provider: :openai,
  api_key: 'sk-your-api-key'
)
```

### Provider-Specific Options

Each provider supports different options:

#### OpenAI (DALL-E)

```ruby
client = Imago.new(provider: :openai)

result = client.generate("A futuristic city", {
  size: '1024x1024',      # '256x256', '512x512', '1024x1024', '1792x1024', '1024x1792'
  quality: 'hd',          # 'standard' or 'hd'
  n: 1,                   # Number of images (1-10)
  response_format: 'url'  # 'url' or 'b64_json'
})

# Access the generated image
result[:images].each do |image|
  puts image[:url]
  puts image[:revised_prompt]  # DALL-E 3 may revise your prompt
end
```

#### Google Gemini (Imagen)

```ruby
client = Imago.new(provider: :gemini)

result = client.generate("A tropical beach", {
  n: 1,                        # Number of images
  aspect_ratio: '16:9',        # Aspect ratio
  negative_prompt: 'people',   # What to exclude
  seed: 12345                  # For reproducibility
})

# Gemini returns base64-encoded images
result[:images].each do |image|
  puts image[:base64]
  puts image[:mime_type]
end
```

#### xAI (Grok)

```ruby
client = Imago.new(provider: :xai)

result = client.generate("A robot playing chess", {
  n: 1,
  response_format: 'url'  # 'url' or 'b64_json'
})

result[:images].each do |image|
  puts image[:url]
end
```

### Image Input (Image-to-Image)

Imago supports image inputs for image editing and image-to-image generation. You can provide images as URLs or base64-encoded data.

```ruby
# URL string (auto-detect mime type from extension)
client = Imago.new(provider: :openai)
result = client.generate("Make this colorful", images: ["https://example.com/photo.jpg"])

# Base64 with explicit mime type
result = client.generate("Add a hat", images: [
  { base64: "iVBORw0KGgo...", mime_type: "image/png" }
])

# URL with explicit mime type (useful when URL has no extension)
result = client.generate("Edit this", images: [
  { url: "https://example.com/photo", mime_type: "image/jpeg" }
])

# Mixed inputs
result = client.generate("Combine these", images: [
  "https://example.com/photo1.jpg",
  { base64: "iVBORw0KGgo...", mime_type: "image/jpeg" }
])
```

#### Image Input Provider Support

| Provider | Support | Limits |
|----------|---------|--------|
| OpenAI | Yes (gpt-image-*, dall-e-2) | 16 images max |
| Gemini | Yes | 10 images max |
| xAI | No | N/A |

**Notes:**
- DALL-E 3 does not support image inputs
- Mime types are auto-detected from URL extensions (png, jpg, jpeg, webp, gif)
- Base64 images require an explicit `mime_type`

### Listing Available Models

```ruby
client = Imago.new(provider: :openai)

# Returns available image generation models
models = client.models
# => ["dall-e-3", "dall-e-2", "gpt-image-1"]
```

For providers with a models API (OpenAI, Gemini), this fetches from the API and caches the result. For providers without such an endpoint (xAI), it returns a curated list of known models.

## Supported Providers

Model list last updated: 01/18/2026.

| Provider | Models | API Key Env Var |
|----------|--------|-----------------|
| OpenAI | `dall-e-3`, `dall-e-2`, `gpt-image-1`, `gpt-image-1.5`, `gpt-image-1-mini` | `OPENAI_API_KEY` |
| Gemini | `imagen-3.0-generate-002`, `imagen-3.0-generate-001`, `gemini-2.0-flash-exp-image-generation`, `gemini-2.5-flash-image`, `gemini-3-pro-image-preview` | `GEMINI_API_KEY` |
| xAI | `grok-2-image`, `grok-2-image-1212` | `XAI_API_KEY` |

## Error Handling

Imago provides specific error classes for different failure scenarios:

```ruby
begin
  client = Imago.new(provider: :openai)
  result = client.generate("A cat")
rescue Imago::AuthenticationError => e
  puts "Invalid API key: #{e.message}"
rescue Imago::RateLimitError => e
  puts "Rate limited: #{e.message}"
rescue Imago::InvalidRequestError => e
  puts "Bad request: #{e.message}"
rescue Imago::ApiError => e
  puts "API error: #{e.message}"
  puts "Status code: #{e.status_code}"
rescue Imago::ConfigurationError => e
  puts "Configuration error: #{e.message}"
rescue Imago::ProviderNotFoundError => e
  puts "Unknown provider: #{e.message}"
rescue Imago::UnsupportedFeatureError => e
  puts "Feature not supported: #{e.message}"
  puts "Provider: #{e.provider}, Feature: #{e.feature}"
end
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests. You can also run `rake rubocop` for linting.

```bash
bundle install
bundle exec rake spec      # Run tests
bundle exec rake rubocop   # Run linter
bundle exec rake           # Run both
```

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
