# QuickBooks Ruby API Example

This example demonstrates how to use the QuickBooks Ruby gem to access the QuickBooks Online API, specifically focusing on accounts payable data.

## Setup

1. Install dependencies:
   ```
   bundle install
   ```

2. Set up your OAuth2 credentials:
   ```
   ruby oauth_setup.rb
   ```
   This will guide you through the OAuth2 authorization process and save your credentials to a `.env` file.

3. Run the accounts payable example:
   ```
   ruby accounts_payable_example.rb
   ```

## What This Example Does

The example demonstrates:

1. **OAuth2 Authorization Flow**: The `oauth_setup.rb` script helps you obtain access and refresh tokens from QuickBooks.

2. **Token Management**: The example automatically refreshes expired tokens.

3. **Accounts Payable Data**: The `accounts_payable_example.rb` script fetches and displays:
   - Bills (unpaid vendor invoices)
   - Bill payments
   - Vendors with outstanding balances
   - Accounts Payable aging report

## Requirements

- Ruby 2.6 or higher
- QuickBooks Online account with API access
- QuickBooks Developer account with an app that has accounting scope

## Troubleshooting

If you encounter any issues:

1. Make sure your QuickBooks app has the correct scopes (accounting)
2. Check that your OAuth credentials are correct
3. Verify that your company ID (realm ID) is correct
4. If tokens expire, run `oauth_setup.rb` again to get fresh tokens

## Documentation

For more information about the QuickBooks Ruby gem, see the [official documentation](https://github.com/ruckus/quickbooks-ruby).