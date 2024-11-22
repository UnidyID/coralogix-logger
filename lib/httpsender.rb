require 'net/http'
require 'json'
require_relative 'constants'
require_relative 'debug_logger'
require 'openssl'
require 'benchmark'
require 'date'
require 'time'

module Coralogix
    # @private
    module CoralogixHTTPSender
        TICKS_IN_SECOND = 10**7
        @initialized = false
        @mutex = Mutex.new

        def CoralogixHTTPSender.disable_proxy value
            @disable_proxy = value
        end

        def CoralogixHTTPSender.disable_proxy=(value)
            @disable_proxy = value
        end

        def CoralogixHTTPSender.initialize
            begin
                @uri = URI(CORALOGIX_LOG_URL)
                if(@disable_proxy)
                    @http = Net::HTTP.new(@uri.host, @uri.port, p_addr=nil, p_port=nil)
                else
                    @http = Net::HTTP.new(@uri.host, @uri.port)
                end
                @http.use_ssl = true
                @http.keep_alive_timeout = 10
                @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                @http.read_timeout = HTTP_TIMEOUT # seconds
                @http.open_timeout = HTTP_TIMEOUT # seconds
                @req = Net::HTTP::Post.new(@uri.path, 'Content-Type' => 'application/json')
                #@req_get = Net::HTTP::Get.new URI(CORALOGIX_TIME_DELTA_URL)
                @initialized = true
            rescue Exception => e  
                    DebugLogger.error e.message  
                    DebugLogger.error e.backtrace.inspect  
                    @initialized = false
            end
            return @initialized
        end

        # A helper method to post http request
        #
        # @param bulk    -   JSON bulk containing the log entries
        def CoralogixHTTPSender.send_request bulk
            @mutex.synchronize do
                self.initialize unless @initialized
                attempt = 0
                while attempt < HTTP_SEND_RETRY_COUNT
                    begin
                        DebugLogger.info "About to send bulk to Coralogix server. Attempt number: #{attempt+1}"  
                        @req.body = bulk.to_json
                        DebugLogger.debug Benchmark.measure { 
                            res = @http.request(@req)
                            DebugLogger.info "Successfully sent bulk to Coralogix server. Result is: #{res.code}"
                        }.to_s
                        return true
                    rescue Exception => e  
                        DebugLogger.error e.message
                        DebugLogger.error e.backtrace.inspect  
                    end
                    attempt+=1;
                    DebugLogger.error "Failed to send bulk. Will retry in: #{HTTP_SEND_RETRY_INTERVAL} seconds..."
                    sleep HTTP_SEND_RETRY_INTERVAL
                end
            end
        end

        # A helper method to get coralogix server current time and calculate the time difference
        #
        # @return [float]    -   time delta
        def CoralogixHTTPSender.get_time_sync
            @mutex.synchronize do
                self.initialize unless @initialized
                begin
                    DebugLogger.info "Syncing time with coralogix server"
                    res = @http.get(CORALOGIX_TIME_DELTA_URL)
                    
                    if res.is_a?(Net::HTTPSuccess) && !res.body.to_s.empty?
                        #Get server ticks from 1970
                        server_ticks = res.body.to_i.to_s # Relative to 1970
                        #Take the first 13 digits
                        server_ticks = server_ticks[0..12]
                        #Convert the ticks to utc time
                        server_time = Time.parse(Time.at(server_ticks.to_i / 1000.to_f).strftime('%H:%M:%S.%L')).utc
                        local_time = Time.now.utc
                        
                        time_delta = (server_time - local_time) * 1000.0
                        DebugLogger.info "Updating time delta to: #{time_delta}"
                        return true, time_delta
                    end
                    return false, 0
                rescue Exception => e  
                    DebugLogger.error e.message  
                    DebugLogger.error e.backtrace.inspect  
                    return false, 0
                end
            end
        end
    end

end
