require 'quickbooks-ruby'
require 'dotenv'
require 'oauth2'

# Load environment variables from .env file
Dotenv.load

# Configure Quickbooks
Quickbooks.log = true

# Set up OAuth2 client
oauth_params = {
  site: "https://appcenter.intuit.com/connect/oauth2",
  authorize_url: "https://appcenter.intuit.com/connect/oauth2",
  token_url: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
}

oauth2_client = OAuth2::Client.new(
  ENV['OAUTH_CLIENT_ID'],
  ENV['OAUTH_CLIENT_SECRET'],
  oauth_params
)

# Create access token object
access_token = OAuth2::AccessToken.new(
  oauth2_client,
  ENV['QUICKBOOKS_ACCESS_TOKEN'],
  refresh_token: ENV['QUICKBOOKS_REFRESH_TOKEN']
)

# Create a service for accounts payable (bills)
service = Quickbooks::Service::Bill.new(
  company_id: ENV['QUICKBOOKS_COMPANY_ID'],
  access_token: access_token
)

# Fetch accounts payable data (bills)
begin
  # Query for bills
  bills = service.query("SELECT * FROM Bill")
  
  puts "Found #{bills.entries.count} bills:"
  puts "-" * 50
  
  bills.entries.each do |bill|
    puts "Bill ##{bill.doc_number || 'N/A'}"
    puts "Vendor: #{bill.vendor_ref.name if bill.vendor_ref}"
    puts "Date: #{bill.txn_date}"
    puts "Amount: $#{bill.total_amount || bill.total}"
    puts "Due Date: #{bill.due_date}"
    puts "Balance: $#{bill.balance}" if bill.balance
    
    if bill.line_items && !bill.line_items.empty?
      puts "Line Items:"
      bill.line_items.each do |line|
        puts "  - #{line.description}: $#{line.amount}"
      end
    end
    
    puts "-" * 50
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end

# You can also query for bill payments
begin
  payment_service = Quickbooks::Service::BillPayment.new(
    company_id: ENV['QUICKBOOKS_COMPANY_ID'],
    access_token: access_token
  )
  
  bill_payments = payment_service.query("SELECT * FROM BillPayment")
  
  puts "\nFound #{bill_payments.entries.count} bill payments:"
  puts "-" * 50
  
  bill_payments.entries.each do |payment|
    puts "Payment ##{payment.doc_number || 'N/A'}"
    puts "Vendor: #{payment.vendor_ref.name if payment.vendor_ref}"
    puts "Date: #{payment.txn_date}"
    puts "Amount: $#{payment.total_amount || payment.total}"
    puts "Payment Type: #{payment.pay_type}"
    
    puts "-" * 50
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end