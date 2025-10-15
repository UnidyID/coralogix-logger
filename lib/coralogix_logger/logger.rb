# frozen_string_literal: true

require "logger"

module Coralogix
  # A Rails 8-compatible logger that sends logs to Coralogix.
  class Logger < ::Logger
    attr_accessor :use_source_file

    # Class-level configuration for stack traces
    @print_stack_trace = false
    @stack_frame = 5

    class << self
      attr_accessor :print_stack_trace, :stack_frame
    end

    # @param name [String] The category for this logger instance.
    def initialize(name)
      # Initialize the standard logger but without a log device (logs go to Coralogix).
      super(nil)
      @category = name
      @use_source_file = true

      # Set a custom formatter to ensure all log messages are valid JSON.
      # If the message is a string, it's wrapped in a JSON object.
      # Otherwise, it's assumed to be a hash and converted to JSON.
      self.formatter = proc do |_severity, _datetime, _progname, msg|
        payload = msg.is_a?(String) ? { message: msg } : msg
        payload.to_json
      end
    end

    # Overrides the standard add method to send logs to Coralogix.
    def add(severity, message = nil, progname = nil)
      severity ||= UNKNOWN
      return true if severity < @level

      progname ||= @category

      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @category
        end
      end

      # Use the formatter to process the message into a JSON string.
      json_message = format_message(format_severity(severity), Time.now, progname, message)

      # Map Ruby's logger severity levels to Coralogix's levels.
      coralogix_severity = case severity
                           when DEBUG then Severity::DEBUG
                           when INFO then Severity::INFO
                           when WARN then Severity::WARNING
                           when ERROR then Severity::ERROR
                           when FATAL then Severity::CRITICAL
                           else Severity::VERBOSE
                           end

      class_name = source_file if @use_source_file
      thread_id = Thread.current.object_id.to_s

      Manager.add_logline(json_message, coralogix_severity, progname, className: class_name, threadId: thread_id)
      true
    end

    # Flushes the logger buffer on close.
    def close
      Manager.flush
    end

    private

    # Return the file name where the call to the logger was made.
    def source_file
      return nil unless self.class.print_stack_trace

      begin
        file_location_path = caller_locations(self.class.stack_frame..self.class.stack_frame).first&.path
        File.basename(file_location_path, File.extname(file_location_path)) if file_location_path
      rescue StandardError => e
        DebugLogger.error "Failed to get source file: #{e.message}"
        nil
      end
    end
  end
end
