# frozen_string_literal: true

require 'singleton'
require 'monitor' # Use the Monitor class for reentrant locking

module Coralogix
  # @private
  # A singleton class that manages buffering and sending logs to Coralogix.
  class Manager
    include Singleton

    # Configures the logger manager with customer-specific values.
    # This must be called before any logs can be sent.
    def configure(private_key:, application_name:, subsystem_name:, ssl_verify_peer: true)
      @mutex.synchronize do
        return if @configured

        @application_name = application_name
        @subsystem_name = subsystem_name
        @computer_name = `hostname`.strip
        @http_sender = HttpSender.new(private_key, ssl_verify_peer: ssl_verify_peer)

        DebugLogger.info "Coralogix Logger configured successfully."
        @configured = true
      end
    end

    # Adds a log line to the buffer.
    def add_logline(message, severity, category, **args)
      return unless @configured

      @mutex.synchronize do
        # Re-initialize buffer if the process has forked
        reinit_if_forked

        if @buffer_size < MAX_LOG_BUFFER_SIZE
          message = self.class.msg2str(message)
          severity = (severity.nil? || severity < Severity::DEBUG || severity > Severity::CRITICAL) ? Severity::DEBUG : severity
          category ||= CORALOGIX_CATEGORY

          new_entry = {
            timestamp: (Time.now.utc.to_f * 1000).round(3),
            severity: severity,
            text: message,
            category: category
          }.merge(args)

          @buffer << new_entry
          @buffer_size += new_entry.to_json.bytesize
        else
          DebugLogger.error "Buffer is full. Dropping log message."
        end
      end
    end

    # Flushes all messages in the buffer immediately.
    def flush
      send_bulk
    end

    # --- Class-level convenience methods ---

    def self.configure(**args)
      instance.configure(**args)
    end

    def self.add_logline(message, severity, category, **args)
      instance.add_logline(message, severity, category, **args)
    end

    def self.flush
      instance.flush
    end

    def self.configured
      instance.instance_variable_get(:@configured)
    end

    private

    def initialize
      @buffer = []
      @buffer_size = 0
      # Use a Monitor for reentrant locking to prevent deadlocks.
      @mutex = Monitor.new
      @process_id = Process.pid
      @configured = false
      run_sender_thread
    end

    # Starts the background thread that periodically sends logs.
    def run_sender_thread
      Thread.new do
        loop do
          send_bulk
          interval = @buffer_size > (MAX_LOG_CHUNK_SIZE / 2) ? FAST_SEND_SPEED_INTERVAL : NORMAL_SEND_SPEED_INTERVAL
          sleep interval
        end
      end.tap { |t| t.priority = 100 }
    end

    # Sends a bulk of logs from the buffer.
    def send_bulk
      return if @buffer.empty?

      logs_to_send = []
      @mutex.synchronize do
        # Determine the size of the chunk to send
        size = chunk_size
        return if size.zero?

        # Take the chunk from the buffer
        logs_to_send = @buffer.shift(size)
        @buffer_size -= logs_to_send.to_json.bytesize # Approximate reduction
        @buffer_size = 0 if @buffer_size.negative?
      end

      # Prepare the final payload outside the mutex
      payload = logs_to_send.map do |log_entry|
        {
          applicationName: @application_name,
          subsystemName: @subsystem_name,
          computerName: @computer_name
        }.merge(log_entry)
      end

      @http_sender.send_request(payload.to_json) unless payload.empty?
    end

    # Calculates the number of logs to take from the buffer.
    def chunk_size
      size = @buffer.size
      while (@buffer.take(size).to_json.bytesize > MAX_LOG_CHUNK_SIZE) && (size > 1)
        size /= 2
      end
      size
    end

    # Resets the buffer if the current process ID is different from the one that started the manager.
    def reinit_if_forked
      return if Process.pid == @process_id

      DebugLogger.info "Process forked. Re-initializing logger buffer."
      @buffer = []
      @buffer_size = 0
      @process_id = Process.pid
    end

    # Converts a log message to a string.
    def self.msg2str(msg)
      case msg
      when ::String
        msg
      when ::Exception
        "#{msg.message} (#{msg.class})\n" << (msg.backtrace || []).join("\n")
      else
        msg.inspect
      end
    rescue StandardError => e
      DebugLogger.error "Failed to convert message to string: #{e.message}"
      "Failed to serialize log message"
    end
  end
end
