# frozen_string_literal: true

# Load all the internal components of the gem.
require_relative "coralogix_logger/version"
require_relative "coralogix_logger/constants"
require_relative "coralogix_logger/debug_logger"
require_relative "coralogix_logger/http_sender"
require_relative "coralogix_logger/manager"
require_relative "coralogix_logger/logger"

# The main module for the Coralogix Ruby logger.
# This module provides the public API for configuring and using the logger.
module Coralogix
  class << self
    # Configures the Coralogix logger with your account details.
    # This must be called once before any loggers are created.
    #
    # @param api_key [String] Your Coralogix Send-Your-Data API key.
    # @param app_name [String] The name of your application.
    # @param sub_system [String] The name of the subsystem within your application.
    # @param ssl_verify_peer [Boolean] Whether to enforce SSL peer verification. Defaults to true.
    def configure(api_key, app_name, sub_system, ssl_verify_peer: true)
      Manager.configure(
        private_key: api_key,
        application_name: app_name,
        subsystem_name: sub_system,
        ssl_verify_peer: ssl_verify_peer
      )
    end

    # Creates a new logger instance.
    #
    # @param name [String] The category name for this logger instance.
    # @return [Coralogix::Logger] A new logger instance.
    def get_logger(name)
      Logger.new(name)
    end

    # Flushes the log buffer, sending all pending logs immediately.
    def flush
      Manager.flush
    end

    # --- SDK Configuration Options ---

    # Enable or disable internal SDK debug logging.
    # When enabled, the SDK will print its own debug messages to a local file.
    def debug_mode=(value)
      DebugLogger.debug_mode = value
    end

    def debug_mode?
      DebugLogger.debug_mode?
    end

    # Enable or disable the inclusion of the source file name in logs.
    def print_stack_trace=(value)
      Logger.print_stack_trace = value
    end

    # Set the stack frame offset to determine the correct source file.
    def stack_frame=(value)
      Logger.stack_frame = value
    end
  end
end
