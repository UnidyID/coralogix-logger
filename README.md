# Coralogix Logger

A Ruby logger that sends logs to [Coralogix](https://coralogix.com/), compatible with Rails 8 and the standard Ruby `Logger` interface.

## Background

This gem was initially based on code extracted from the `coralogix_logger` gem v0.0.25, which may have been the property of [Coralogix Ltd.](https://coralogix.com/docs/integrations/sdks/ruby/). Since then, it has been extensively rewritten and should be considered its own independent project.

## Features

- Drop-in replacement for Ruby's standard `Logger`
- Rails 8 compatible
- Asynchronous log delivery with background thread
- Automatic buffering and bulk sending
- Fork-safe (works with Puma, Unicorn, etc.)
- Configurable Coralogix endpoint via environment variable
- SSL verification and proxy configuration options

## Installation

Add this line to your application's Gemfile:

```ruby
gem "coralogix_logger", git: "https://github.com/UnidyID/coralogix-logger"
```

Then execute:

```bash
bundle install
```

## Usage

### Configuration

Configure the logger once at application startup (e.g., in a Rails initializer):

```ruby
Coralogix.configure(
  "your-api-key",        # Coralogix Send-Your-Data API key
  "MyApplication",       # Application name
  "MySubsystem",         # Subsystem name
  ssl_verify_peer: true, # Optional: SSL verification (default: true)
  disable_proxy: false   # Optional: Disable HTTP proxy (default: false)
)
```

### Creating a Logger

```ruby
logger = Coralogix.get_logger("MyCategory")

logger.info "User signed in"
logger.warn "Rate limit approaching"
logger.error "Payment failed"
logger.debug { "Expensive debug info: #{expensive_calculation}" }
```

### Using with Rails

Create an initializer `config/initializers/coralogix.rb`:

```ruby
if Rails.env.production?
  Coralogix.configure(
    ENV.fetch("CORALOGIX_API_KEY"),
    ENV.fetch("APP_NAME"),
    ENV.fetch("APP_SUBSYSTEM", "app")
  )

  # Broadcast logs to Coralogix while keeping the default Rails logger
  Rails.logger.broadcast_to(Coralogix.get_logger("Rails"))
end
```

This keeps your default Rails logger (STDOUT, file, etc.) while also sending logs to Coralogix.

Alternatively, to use Coralogix as the sole logger, set it in `config/environments/production.rb`:

```ruby
config.logger = Coralogix.get_logger("Rails")
```

### Structured Logging

Pass a hash for structured JSON logs:

```ruby
logger.info({ event: "order_placed", order_id: 123, amount: 99.99 })
```

### Flushing Logs

Logs are sent asynchronously in batches. To flush immediately (e.g., before shutdown):

```ruby
Coralogix.flush
```

### Debug Mode

Enable internal SDK debug logging (writes to `coralogix.sdk.log`):

```ruby
Coralogix.debug_mode = true
```

### Custom Endpoint

Set the `CORALOGIX_LOG_URL` environment variable to use a different Coralogix endpoint:

```bash
export CORALOGIX_LOG_URL="https://ingress.coralogix.us/logs/v1/singles"
```

Default: `https://ingress.eu2.coralogix.com/logs/v1/singles`

## Puma and Unicorn

This gem automatically handles process forking. When a fork is detected (e.g., when Puma or Unicorn spawns worker processes), the logger automatically reinitializes its buffer, HTTP connection, and sender thread on the first log write.

**No manual configuration is required** - unlike the original `coralogix_logger` gem which required calling `reconnect` in `on_worker_boot` or `after_fork` hooks, this gem handles it transparently.

If you want to force immediate reconnection after fork (rather than waiting for the first log), you can call `Coralogix.flush` in your worker boot hook:

```ruby
# config/puma.rb (optional - not required)
on_worker_boot do
  Coralogix.flush
end
```

```ruby
# config/unicorn.rb (optional - not required)
after_fork do |server, worker|
  Coralogix.flush
end
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `api_key` | String | required | Your Coralogix Send-Your-Data API key |
| `app_name` | String | required | Application name shown in Coralogix |
| `sub_system` | String | required | Subsystem name for log categorization |
| `ssl_verify_peer` | Boolean | `true` | Verify SSL certificates |
| `disable_proxy` | Boolean | `false` | Disable HTTP proxy usage |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
git clone https://github.com/UnidyID/coralogix-logger.git
cd coralogix-logger
bin/setup
rake spec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/UnidyID/coralogix-logger. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/UnidyID/coralogix-logger/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/UnidyID/coralogix-logger/blob/main/CODE_OF_CONDUCT.md).