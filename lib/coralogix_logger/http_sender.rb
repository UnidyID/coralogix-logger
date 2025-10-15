# frozen_string_literal: true

require "net/http"
require "json"
require "openssl"

# Conditionally load the benchmark library to make it an optional dependency.
begin
  require "benchmark"
  BENCHMARK_ENABLED = true
rescue LoadError
  BENCHMARK_ENABLED = false
end

module Coralogix
  # @private
  # A class to handle sending log bulks to the Coralogix REST API endpoint.
  class HttpSender
    # @param api_key [String] The Coralogix Send-Your-Data API key.
    # @param ssl_verify_peer [Boolean] Whether to enforce SSL peer verification.
    # @param disable_proxy [Boolean] Whether to disable HTTP proxy usage.
    def initialize(api_key, ssl_verify_peer: true, disable_proxy: false)
      @uri = URI(CORALOGIX_LOG_URL)

      proxy_addr = disable_proxy ? nil : :ENV
      @http = Net::HTTP.new(@uri.host, @uri.port, proxy_addr)
      @http.use_ssl = true
      @http.keep_alive_timeout = 10
      @http.verify_mode = ssl_verify_peer ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      @http.read_timeout = HTTP_TIMEOUT
      @http.open_timeout = HTTP_TIMEOUT

      @req = Net::HTTP::Post.new(
        @uri.path,
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{api_key}"
      )
    rescue StandardError => e
      DebugLogger.error "Failed to initialize HttpSender: #{e.message}"
      DebugLogger.error e.backtrace.inspect
      raise
    end

    # Sends a JSON string to the Coralogix endpoint.
    #
    # @param json_bulk [String] A JSON string representing an array of log entries.
    # @return [Boolean] True if the request was successful, false otherwise.
    def send_request(json_bulk)
      attempt = 0
      while attempt < HTTP_SEND_RETRY_COUNT
        begin
          DebugLogger.info "About to send to Coralogix. Attempt: #{attempt + 1}"
          @req.body = json_bulk

          res = nil
          if BENCHMARK_ENABLED
            DebugLogger.debug(Benchmark.measure { res = @http.request(@req) }.to_s)
          else
            res = @http.request(@req)
          end

          if res.is_a?(Net::HTTPSuccess)
            DebugLogger.info "Successfully sent bulk to Coralogix. Result: #{res.code}"
            return true
          else
            DebugLogger.error "Failed to send bulk to Coralogix. Status: #{res.code}, Body: #{res.body}"
          end

        rescue StandardError => e
          DebugLogger.error "Exception during HTTP request: #{e.message}"
          DebugLogger.error e.backtrace.inspect
        end

        attempt += 1
        DebugLogger.error "Retrying in #{HTTP_SEND_RETRY_INTERVAL} seconds..."
        sleep HTTP_SEND_RETRY_INTERVAL
      end

      DebugLogger.error "Failed to send bulk after #{HTTP_SEND_RETRY_COUNT} attempts."
      false
    end
  end
end
