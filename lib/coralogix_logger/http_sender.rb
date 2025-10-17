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
      @http = default_http_request(proxy_addr, ssl_verify_peer)

      @req = Net::HTTP::Post.new(@uri.path, "Content-Type": "application/json", Authorization: "Bearer #{api_key}")
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
      HTTP_SEND_RETRY_COUNT.times do |attempt|
        DebugLogger.info "About to send to Coralogix. Attempt: #{attempt + 1}"
        return true if attempt_send(json_bulk)

        if attempt < HTTP_SEND_RETRY_COUNT - 1
          DebugLogger.error "Retrying in #{HTTP_SEND_RETRY_INTERVAL} seconds..."
          sleep HTTP_SEND_RETRY_INTERVAL
        end
      end

      DebugLogger.error "Failed to send bulk after #{HTTP_SEND_RETRY_COUNT} attempts."
      false
    end

    private

    def default_http_request(proxy_addr, ssl_verify_peer)
      http = Net::HTTP.new(@uri.host, @uri.port, proxy_addr)
      http.use_ssl = true
      http.keep_alive_timeout = 10
      http.verify_mode = ssl_verify_peer ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = HTTP_TIMEOUT
      http.open_timeout = HTTP_TIMEOUT
      http
    end

    def attempt_send(json_bulk)
      @req.body = json_bulk
      res = perform_request
      handle_response(res)
    rescue StandardError => e
      DebugLogger.error "Exception during HTTP request: #{e.message}"
      DebugLogger.error e.backtrace.inspect
      false
    end

    def perform_request
      if BENCHMARK_ENABLED
        res = nil
        DebugLogger.debug(Benchmark.measure { res = @http.request(@req) }.to_s)
        res
      else
        @http.request(@req)
      end
    end

    def handle_response(res)
      if res.is_a?(Net::HTTPSuccess)
        DebugLogger.info "Successfully sent bulk to Coralogix. Result: #{res.code}"
        true
      else
        DebugLogger.error "Failed to send bulk to Coralogix. Status: #{res.code}, Body: #{res.body}"
        false
      end
    end
  end
end
