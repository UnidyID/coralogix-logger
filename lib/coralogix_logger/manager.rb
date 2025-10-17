# frozen_string_literal: true

require "singleton"
require "monitor"

module Coralogix
  # @private
  # A singleton class that manages buffering and sending logs to Coralogix.
  class Manager # rubocop:disable Metrics/ClassLength
    include Singleton

    MAX_LOG_BUFFER_SIZE = 1_000_000 # Add if constants aren’t already defined elsewhere
    MAX_LOG_CHUNK_SIZE = 65_536
    NORMAL_SEND_SPEED_INTERVAL = 5
    FAST_SEND_SPEED_INTERVAL = 1
    CORALOGIX_CATEGORY = "default"

    def initialize
      @buffer = []
      @buffer_size = 0
      @mutex = Monitor.new
      @process_id = Process.pid
      @configured = false
      run_sender_thread
    end

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

    def add_logline(message, severity, category, **args) # rubocop:disable Metrics/MethodLength
      return unless @configured

      @mutex.synchronize do
        reinit_if_forked

        if @buffer_size < MAX_LOG_BUFFER_SIZE
          message = msg2str(message)
          severity = Severity::DEBUG if severity.nil? || severity < Severity::DEBUG || severity > Severity::CRITICAL
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

    def flush
      send_bulk
    end

    # --- Class-level convenience methods ---
    class << self
      def configure(**args) = instance.configure(**args)
      def add_logline(message, severity, category, **args) = instance.add_logline(message, severity, category, **args)
      def flush = instance.flush
      def configured = instance.instance_variable_get(:@configured)
    end

    private

    def run_sender_thread
      thread = Thread.new do
        loop do
          send_bulk
          interval = @buffer_size > (MAX_LOG_CHUNK_SIZE / 2) ? FAST_SEND_SPEED_INTERVAL : NORMAL_SEND_SPEED_INTERVAL
          sleep interval
        end
      end
      thread.priority = 100
      thread
    end

    def send_bulk # rubocop:disable Metrics/MethodLength
      return if @buffer.empty?

      logs_to_send = []
      @mutex.synchronize do
        size = chunk_size
        return if size.zero?

        logs_to_send = @buffer.shift(size)
        @buffer_size -= logs_to_send.to_json.bytesize
        @buffer_size = 0 if @buffer_size.negative?
      end

      payload = logs_to_send.map do |log_entry|
        {
          applicationName: @application_name,
          subsystemName: @subsystem_name,
          computerName: @computer_name
        }.merge(log_entry)
      end

      @http_sender.send_request(payload.to_json) unless payload.empty?
    end

    def chunk_size
      size = @buffer.size
      size /= 2 while (@buffer.take(size).to_json.bytesize > MAX_LOG_CHUNK_SIZE) && size > 1
      size
    end

    def reinit_if_forked
      return if Process.pid == @process_id

      DebugLogger.info "Process forked. Re-initializing logger buffer."
      @buffer.clear
      @buffer_size = 0
      @process_id = Process.pid
    end

    def msg2str(msg) # rubocop:disable Metrics/MethodLength
      case msg
      when ::String
        msg
      when ::Exception
        "#{msg.message} (#{msg.class})\n#{(msg.backtrace || []).join("\n")}"
      else
        msg.inspect
      end
    rescue StandardError => e
      DebugLogger.error "Failed to convert message to string: #{e.message}"
      "Failed to serialize log message"
    end
  end
end
