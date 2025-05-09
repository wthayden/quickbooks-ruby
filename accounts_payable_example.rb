require 'quickbooks-ruby'
require 'dotenv'
require 'oauth2'
require 'date'

# Load environment variables from .env file
Dotenv.load

# Check if we have the required environment variables
required_vars = %w[
  OAUTH_CLIENT_ID 
  OAUTH_CLIENT_SECRET 
  QUICKBOOKS_COMPANY_ID 
  QUICKBOOKS_ACCESS_TOKEN 
  QUICKBOOKS_REFRESH_TOKEN
]

missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
if missing_vars.any?
  puts "Error: Missing required environment variables: #{missing_vars.join(', ')}"
  puts "Please run oauth_setup.rb first to set up your OAuth credentials."
  exit 1
end

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
  refresh_token: ENV['QUICKBOOKS_REFRESH_TOKEN'],
  expires_at: ENV['QUICKBOOKS_TOKEN_EXPIRES_AT']&.to_i
)

# Check if token needs refresh
if access_token.expires_at && access_token.expires_at < Time.now.to_i
  puts "Access token has expired, refreshing..."
  begin
    access_token = access_token.refresh!
    # Update the .env file with new tokens
    env_content = File.read('.env').
      gsub(/QUICKBOOKS_ACCESS_TOKEN=.*/, "QUICKBOOKS_ACCESS_TOKEN=#{access_token.token}").
      gsub(/QUICKBOOKS_REFRESH_TOKEN=.*/, "QUICKBOOKS_REFRESH_TOKEN=#{access_token.refresh_token}").
      gsub(/QUICKBOOKS_TOKEN_EXPIRES_AT=.*/, "QUICKBOOKS_TOKEN_EXPIRES_AT=#{access_token.expires_at}")
    
    File.write('.env', env_content)
    puts "Tokens refreshed and saved to .env file"
  rescue => e
    puts "Error refreshing token: #{e.message}"
    puts "You may need to reauthorize by running oauth_setup.rb again"
    exit 1
  end
end

# Create a service for accounts payable (bills)
bill_service = Quickbooks::Service::Bill.new(
  company_id: ENV['QUICKBOOKS_COMPANY_ID'],
  access_token: access_token
)

# Function to format currency
def format_currency(amount)
  return "N/A" if amount.nil?
  "$#{amount.to_f.round(2)}"
end

# Function to format date
def format_date(date)
  return "N/A" if date.nil?
  date.to_s
end

# Fetch accounts payable data (bills)
begin
  # Query for bills
  puts "Fetching bills..."
  bills = bill_service.query("SELECT * FROM Bill")
  
  puts "\nFound #{bills.entries.count} bills:"
  puts "=" * 80
  
  bills.entries.each do |bill|
    puts "Bill ##{bill.doc_number || 'N/A'}"
    puts "Vendor: #{bill.vendor_ref&.name || 'N/A'}"
    puts "Date: #{format_date(bill.txn_date)}"
    puts "Amount: #{format_currency(bill.total)}"
    puts "Due Date: #{format_date(bill.due_date)}"
    puts "Balance: #{format_currency(bill.balance)}"
    
    if bill.line_items && !bill.line_items.empty?
      puts "\nLine Items:"
      bill.line_items.each do |line|
        puts "  - #{line.description || 'No description'}: #{format_currency(line.amount)}"
        
        # Show account details for account-based expenses
        if line.account_based_expense_item? && line.account_based_expense_line_detail
          detail = line.account_based_expense_line_detail
          puts "    Account: #{detail.account_ref&.name || 'N/A'}"
          puts "    Billable: #{detail.billable_status || 'N/A'}"
        end
        
        # Show item details for item-based expenses
        if line.item_based_expense_item? && line.item_based_expense_line_detail
          detail = line.item_based_expense_line_detail
          puts "    Item: #{detail.item_ref&.name || 'N/A'}"
          puts "    Quantity: #{detail.quantity || 'N/A'}"
          puts "    Unit Price: #{format_currency(detail.unit_price)}"
        end
      end
    end
    
    puts "=" * 80
  end
  
rescue => e
  puts "Error fetching bills: #{e.message}"
  puts e.backtrace
end

# Fetch bill payments
begin
  payment_service = Quickbooks::Service::BillPayment.new(
    company_id: ENV['QUICKBOOKS_COMPANY_ID'],
    access_token: access_token
  )
  
  puts "\nFetching bill payments..."
  bill_payments = payment_service.query("SELECT * FROM BillPayment")
  
  puts "\nFound #{bill_payments.entries.count} bill payments:"
  puts "=" * 80
  
  bill_payments.entries.each do |payment|
    puts "Payment ##{payment.doc_number || 'N/A'}"
    puts "Vendor: #{payment.vendor_ref&.name || 'N/A'}"
    puts "Date: #{format_date(payment.txn_date)}"
    puts "Amount: #{format_currency(payment.total)}"
    puts "Payment Type: #{payment.pay_type || 'N/A'}"
    
    if payment.line_items && !payment.line_items.empty?
      puts "\nPayment Applied To:"
      payment.line_items.each do |line|
        puts "  - Amount: #{format_currency(line.amount)}"
        
        if line.linked_transactions && !line.linked_transactions.empty?
          line.linked_transactions.each do |linked_txn|
            puts "    Linked to #{linked_txn.txn_type} ##{linked_txn.txn_id}"
          end
        end
      end
    end
    
    puts "=" * 80
  end
  
rescue => e
  puts "Error fetching bill payments: #{e.message}"
  puts e.backtrace
end

# Fetch vendors
begin
  vendor_service = Quickbooks::Service::Vendor.new(
    company_id: ENV['QUICKBOOKS_COMPANY_ID'],
    access_token: access_token
  )
  
  puts "\nFetching vendors with outstanding balances..."
  vendors = vendor_service.query("SELECT * FROM Vendor WHERE Balance > '0'")
  
  puts "\nFound #{vendors.entries.count} vendors with outstanding balances:"
  puts "=" * 80
  
  vendors.entries.each do |vendor|
    puts "Vendor: #{vendor.display_name}"
    puts "Company: #{vendor.company_name}" if vendor.company_name
    puts "Balance: #{format_currency(vendor.balance)}"
    
    if vendor.billing_address
      puts "Address: #{[
        vendor.billing_address.line1,
        vendor.billing_address.line2,
        vendor.billing_address.city,
        vendor.billing_address.country_sub_division_code,
        vendor.billing_address.postal_code
      ].compact.join(', ')}"
    end
    
    puts "=" * 80
  end
  
rescue => e
  puts "Error fetching vendors: #{e.message}"
  puts e.backtrace
end

puts "\nAccounts Payable Summary:"
puts "=" * 80
begin
  report_service = Quickbooks::Service::Reports.new(
    company_id: ENV['QUICKBOOKS_COMPANY_ID'],
    access_token: access_token
  )
  
  # Get the A/P Aging Summary report
  ap_aging = report_service.query('AgedPayables')
  
  if ap_aging && ap_aging.rows
    puts "Accounts Payable Aging Summary:"
    ap_aging.all_rows.each do |row|
      # Skip header rows and summary rows that don't have values
      next if row.all? { |cell| cell.nil? || cell.to_s.strip.empty? }
      puts row.map { |cell| cell.to_s.ljust(20) }.join(' | ')
    end
  else
    puts "No A/P aging data available"
  end
rescue => e
  puts "Error fetching A/P aging report: #{e.message}"
end

puts "=" * 80
puts "Example completed successfully!"