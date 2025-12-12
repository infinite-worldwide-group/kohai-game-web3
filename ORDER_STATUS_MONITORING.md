# Order Status Monitoring System

## Overview

Automatic monitoring system that checks the status of processing orders from the vendor API and updates order status accordingly.

## How It Works

### 1. Order Flow

```
User Payment → Order.processing → Vendor API Purchase → Order.check_vendor_status → Order.succeeded/failed
```

### 2. Automatic Status Checking

The system automatically checks processing orders every **3 minutes** using a background job:

- **Job**: `CheckProcessingOrdersJob`
- **Frequency**: Every 3 minutes (configured in `config/schedule.yml`)
- **Condition**: Only checks orders that:
  - Are in `processing` status
  - Have an `invoice_id` from vendor
  - Haven't been updated in the last 5 minutes (to avoid spam)

### 3. Vendor Status Mapping

| Vendor Status | Order Action | Order Status |
|--------------|--------------|--------------|
| `succeeded` | `order.success!` | `succeeded` |
| `failed` | `order.fail!` | `failed` |
| `cancelled` | `order.fail!` | `failed` |
| `processing` | No action | `processing` |
| `pending` | No action | `processing` |

## Manual Usage

### Check a Single Order

```ruby
# Find an order
order = Order.find_by(order_number: "ORD-1765360649-0E184E02")

# Check its status from vendor
order.check_vendor_status
# => true (if status was updated)
# => false (if status unchanged or error)

# Check updated status
order.reload.status
# => "succeeded" or "failed"
```

### Check All Processing Orders

```ruby
# Get all orders that need status check
orders = Order.needs_status_check

# Check each one
orders.each do |order|
  order.check_vendor_status
end
```

### Run the Background Job Manually

```ruby
# Run the job immediately
CheckProcessingOrdersJob.perform_now

# Or enqueue it to run async
CheckProcessingOrdersJob.perform_later
```

## Example API Response from Vendor

```ruby
vendor = VendorService.check_order_detail("ORD-1765360649-0E184E02", "33375390")
# =>
# {
#   "message" => "Success",
#   "data" => {
#     "invoiceId" => "33375390",
#     "reference" => "ORD-1765360649-0E184E02",
#     "retailPrice" => "0.73",
#     "status" => "succeeded",
#     "productName" => "Honor of Kings",
#     "productItemName" => "16 Tokens",
#     "data" => {"Player ID" => "7264265174721866791"},
#     "trxDate" => "2025-12-10T10:33:32.774Z"
#   }
# }
```

## Database Schema

The order status check is logged in `vendor_transaction_logs`:

```ruby
# Example log entry
{
  order_id: 123,
  vendor_name: "status_check",
  request_body: '{"order_number":"ORD-1765360649-0E184E02","invoice_id":"33375390"}',
  response_body: '{"message":"Success","data":{...}}',
  status: "succeeded",
  executed_at: "2025-12-11 10:30:00"
}
```

## Monitoring & Troubleshooting

### Check Job Status

```ruby
# Check if job is scheduled
Sidekiq::Cron::Job.find('check_processing_orders')
# => Shows job configuration and next run time

# Check recent job executions
Sidekiq::Cron::Job.find('check_processing_orders').history
# => Shows last 10 executions
```

### View Processing Orders

```ruby
# Count processing orders
Order.processing_with_invoice.count

# List orders needing check
Order.needs_status_check.pluck(:order_number, :invoice_id, :updated_at)

# Find stuck orders (processing > 1 hour)
Order.where(status: 'processing')
     .where.not(invoice_id: nil)
     .where('updated_at < ?', 1.hour.ago)
```

### View Logs

```bash
# Rails logs
tail -f log/development.log | grep "CheckProcessingOrdersJob"

# Sidekiq logs (production)
tail -f log/sidekiq.log | grep "CheckProcessingOrdersJob"
```

### Check Vendor Transaction Logs

```ruby
# Get all status check logs for an order
order = Order.find_by(order_number: "ORD-XXX")
order.vendor_transaction_logs.where(vendor_name: 'status_check')

# Check recent status checks
VendorTransactionLog.where(vendor_name: 'status_check')
                     .order(created_at: :desc)
                     .limit(10)
```

## Configuration

### Adjust Check Frequency

Edit `config/schedule.yml`:

```yaml
check_processing_orders:
  cron: "*/3 * * * *"  # Every 3 minutes (default)
  # cron: "*/1 * * * *"  # Every 1 minute (faster)
  # cron: "*/5 * * * *"  # Every 5 minutes (slower)
  class: "CheckProcessingOrdersJob"
  queue: default
```

After changing, reload Sidekiq cron:

```ruby
Sidekiq::Cron::Job.load_from_hash(YAML.load_file('config/schedule.yml'))
```

### Adjust Time Threshold

Edit `app/jobs/check_processing_orders_job.rb`:

```ruby
# Change from 5 minutes to 2 minutes
.where('updated_at < ?', 2.minutes.ago)
```

### Adjust Batch Size

Edit `app/jobs/check_processing_orders_job.rb`:

```ruby
# Change from 50 to 100 orders per run
.limit(100)
```

## Error Handling

The system handles errors gracefully:

1. **API Failures**: If vendor API is down, order stays in `processing` and will be checked again in next run
2. **Invalid Response**: Logged as warning, order remains in `processing`
3. **Unknown Status**: Logged as warning, order remains in `processing`
4. **Network Timeout**: Caught and logged, order will be retried

All errors are logged to Rails logger with details.

## Testing

### Test in Rails Console

```ruby
# Create a test scenario (don't run in production!)
order = Order.processing_with_invoice.first

# Mock the vendor response (for testing only)
allow(VendorService).to receive(:check_order_detail).and_return({
  'message' => 'Success',
  'data' => {
    'status' => 'succeeded',
    'invoiceId' => order.invoice_id
  }
})

# Check status
order.check_vendor_status
# => true

order.reload.status
# => "succeeded"
```

### Test the Background Job

```ruby
# Enqueue the job for immediate execution
CheckProcessingOrdersJob.perform_now

# Check the logs
tail -f log/development.log
```

## Best Practices

1. **Monitor Stuck Orders**: Set up alerts for orders stuck in `processing` for > 1 hour
2. **Rate Limiting**: The job includes 0.5s delay between API calls to avoid rate limiting
3. **Batch Processing**: Only processes 50 orders per run to avoid timeout
4. **Idempotent**: Safe to run multiple times, won't double-update orders
5. **Logging**: All checks are logged in `vendor_transaction_logs` for audit trail

## Alerting (Recommended)

Set up alerts for:

```ruby
# Orders stuck in processing for > 1 hour
Order.where(status: 'processing')
     .where('updated_at < ?', 1.hour.ago)
     .where.not(invoice_id: nil)
     .count > 10

# High error rate in status checks
VendorTransactionLog.where(vendor_name: 'status_check')
                     .where(status: 'error')
                     .where('created_at > ?', 1.hour.ago)
                     .count > 20
```

## Manual Intervention

If an order is stuck and needs manual intervention:

```ruby
# Find the order
order = Order.find_by(order_number: "ORD-XXX")

# Check vendor manually
response = VendorService.check_order_detail(order.order_number, order.invoice_id)

# Manually update if needed
if response['data']['status'] == 'succeeded'
  order.success!
  puts "✓ Order marked as succeeded"
elsif response['data']['status'] == 'failed'
  order.fail!
  puts "✗ Order marked as failed"
end
```

## Sidekiq Setup

Make sure Sidekiq is running with cron enabled:

```bash
# Start Sidekiq with cron
bundle exec sidekiq -C config/sidekiq.yml

# Or using Procfile
foreman start
```

The cron jobs will be loaded automatically from `config/schedule.yml` when Sidekiq starts.
