# frozen_string_literal: true

require "logger"

module Coralogix
  # @private
  # Internal logger for the Coralogix SDK. Enabled by setting `debug_mode = true`.
  class DebugLogger
    def self.initialize
      @mutex = Mutex.new
      @debug = false
    rescue StandardError => e
      puts "Error initializing DebugLogger: #{e.message}" if @debug
    end

    def self.debug_mode?
      @debug
    end

    def self.debug_mode=(value)
      @debug = value
      if value && @logger.nil?
        @logger = ::Logger.new(LOG_FILE_NAME, 1, 10_485_760) # 10MB file size
      elsif !value && @logger
        @logger.close
        @logger = nil
      end
    rescue StandardError => e
      puts "Error setting debug mode: #{e.message}" if @debug
    end

    # Define methods for each log level (debug, info, warn, error, fatal)
    ::Logger::Severity.constants.each do |level|
      define_singleton_method(level.downcase) do |*args|
        return unless @debug && @logger

        @mutex.synchronize do
          message = "#{Time.now.strftime("%Y-%m-%d %H:%M:%S.%L")} - #{args.join(" ")}"
          puts "CORALOGIX_SDK_DEBUG: #{message}"
          @logger.send(level.downcase, message)
        rescue StandardError => e
          puts "Error in DebugLogger: #{e.message}"
        end
      end
    end

    initialize
  end
end
