require 'oauth2'
require 'webrick'
require 'dotenv'

# Load environment variables if .env file exists
Dotenv.load if File.exist?('.env')

# Set up your app credentials
client_id = ENV['OAUTH_CLIENT_ID'] || 'YOUR_CLIENT_ID'
client_secret = ENV['OAUTH_CLIENT_SECRET'] || 'YOUR_CLIENT_SECRET'
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
puts "\nAfter authorization, you'll be redirected to localhost:8080/callback"

# Start a simple web server to handle the callback
server = WEBrick::HTTPServer.new(Port: 8080)

server.mount_proc '/callback' do |req, res|
  code = req.query['code']
  realm_id = req.query['realmId']
  
  puts "\nAuthorization code: #{code}"
  puts "Realm ID (Company ID): #{realm_id}"
  
  # Exchange authorization code for tokens
  begin
    token = client.auth_code.get_token(
      code,
      redirect_uri: redirect_uri
    )
    
    puts "\n=== SAVE THESE VALUES IN YOUR .ENV FILE ==="
    puts "OAUTH_CLIENT_ID=#{client_id}"
    puts "OAUTH_CLIENT_SECRET=#{client_secret}"
    puts "QUICKBOOKS_COMPANY_ID=#{realm_id}"
    puts "QUICKBOOKS_ACCESS_TOKEN=#{token.token}"
    puts "QUICKBOOKS_REFRESH_TOKEN=#{token.refresh_token}"
    puts "QUICKBOOKS_TOKEN_EXPIRES_AT=#{token.expires_at}"
    puts "=== END OF VALUES ==="
    
    # Create or update .env file
    env_content = <<~ENV
      # QuickBooks OAuth2 credentials
      OAUTH_CLIENT_ID=#{client_id}
      OAUTH_CLIENT_SECRET=#{client_secret}
      QUICKBOOKS_COMPANY_ID=#{realm_id}
      QUICKBOOKS_ACCESS_TOKEN=#{token.token}
      QUICKBOOKS_REFRESH_TOKEN=#{token.refresh_token}
      QUICKBOOKS_TOKEN_EXPIRES_AT=#{token.expires_at}
    ENV
    
    File.write('.env', env_content)
    puts "\nCredentials have been saved to .env file"
    
    res.body = "Authorization successful! Check your console for the tokens. You can close this window now."
  rescue => e
    puts "Error getting token: #{e.message}"
    res.body = "Error: #{e.message}"
  end
  
  server.shutdown
end

trap('INT') { server.shutdown }
puts "\nStarting local server at http://localhost:8080 to receive the callback..."
server.start