# QuickBooks Ruby Example

This is a simple example application that demonstrates how to use the QuickBooks Ruby gem to access the QuickBooks Online API.

## Setup

1. Copy the `.env.example` file to `.env`:
   ```
   cp .env.example .env
   ```

2. Edit the `.env` file and add your QuickBooks API credentials:
   - `OAUTH_CLIENT_ID`: Your QuickBooks app's client ID
   - `OAUTH_CLIENT_SECRET`: Your QuickBooks app's client secret
   - `QUICKBOOKS_COMPANY_ID`: Your QuickBooks company ID (also known as realm ID)
   - `QUICKBOOKS_ACCESS_TOKEN`: Your OAuth2 access token
   - `QUICKBOOKS_REFRESH_TOKEN`: Your OAuth2 refresh token

3. Install the required gems:
   ```
   bundle install
   ```

## Running the Example

Run the example script:
```
ruby example.rb
```

This will fetch and display accounts payable data (bills and bill payments) from your QuickBooks Online account.

## Getting OAuth2 Tokens

If you don't have OAuth2 tokens yet, you'll need to go through the OAuth2 authorization flow. Here's a simple script to help with that:

```ruby
require 'oauth2'
require 'webrick'

# Set up your app credentials
client_id = 'YOUR_CLIENT_ID'
client_secret = 'YOUR_CLIENT_SECRET'
redirect_uri = 'http://localhost:8080/callback'

# Set up OAuth2 client
client = OAuth2::Client.new(
  client_id,
  client_secret,
  site: 'https://appcenter.intuit.com/connect/oauth2',
  authorize_url: 'https://appcenter.intuit.com/connect/oauth2',
  token_url: 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'
)

# Generate authorization URL
auth_url = client.auth_code.authorize_url(
  redirect_uri: redirect_uri,
  response_type: 'code',
  scope: 'com.intuit.quickbooks.accounting'
)

puts "Visit this URL to authorize the app:"
puts auth_url

# Start a simple web server to handle the callback
server = WEBrick::HTTPServer.new(Port: 8080)

server.mount_proc '/callback' do |req, res|
  code = req.query['code']
  realmId = req.query['realmId']
  
  puts "Authorization code: #{code}"
  puts "Realm ID: #{realmId}"
  
  # Exchange authorization code for tokens
  token = client.auth_code.get_token(
    code,
    redirect_uri: redirect_uri
  )
  
  puts "Access token: #{token.token}"
  puts "Refresh token: #{token.refresh_token}"
  puts "Expires at: #{token.expires_at}"
  
  res.body = "Authorization successful! Check your console for the tokens."
  server.shutdown
end

trap('INT') { server.shutdown }
server.start
```

Save this as `oauth_setup.rb` and run it with `ruby oauth_setup.rb`. Follow the URL it provides to authorize your app, and it will print out the tokens you need.