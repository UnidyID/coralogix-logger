require_relative 'httpsender'
require_relative 'constants'
require_relative 'debug_logger'
require 'date'
require 'time'

module Coralogix
    # @private
    class LoggerManager

        class << self
            attr_accessor :configured
        end

        def self.initialize
            @bulk_template = {:privateKey => FAILED_PRIVATE_KEY, :applicationName => NO_APP_NAME, :subsystemName => NO_SUB_SYSTEM}
            @time_delta_last_update = 0
            @time_delta = 0
            self.init
        end

        def self.init
            @buffer = []
            @buffer_size = 0
            @mutex = Mutex.new
            @process= Process.pid
            self.run
        end

        # Add a log line to our buffer.
        #
        # @param **args    -   Customer parameters:
        #                           privateKey - Private Key
        #                           applicationName - Application name
        #                           subsystemName - Subsystem name
        # @return [boolean] return true for success or false for failure.
        def self.configure **args
            begin
                @bulk_template = args.merge({:computerName => `hostname`.strip})
                DebugLogger.info "Successfully configured Coralogix logger."
                @configured = true                
                #self.update_time_delta_interval
                self.add_logline "The Application Name #{@bulk_template[:applicationName]} and Subsystem Name #{@bulk_template[:subsystemName]} from the Ruby SDK, version #{self.version?} has started to send data.", Severity::INFO, CORALOGIX_CATEGORY 
            rescue Exception => e  
                DebugLogger.error e.message  
                DebugLogger.error e.backtrace.inspect
                @configured = false
            end
            return @configured
        end

        def self.version?
            begin
                Gem.loaded_specs['coralogix_logger'].version.to_s
            rescue Exception => e  
                DebugLogger.error e.message  
                DebugLogger.error e.backtrace.inspect
                return '0.0.0'
            end
        end


        # Add a log line to our buffer.
        #
        # @param message    -   The logs message. This is a must parameter.
        # @param severity   -   The severity of the log message. This is a must parameter.
        # @param category   -   The category (logger name) of the message. This is a must parameter.
        # @param **args     -   Optional parameters. It can be:
        #                           className - The class name where the log message was sent from.
        #                           methodName - The method name where the log message was sent from.
        #                           threadId -  The thread id where the log message was sent from.
        # @return [boolean] return true for success or false for failure.
        def self.add_logline message, severity, category, **args
            begin
               return if @mutex.nil?
                @mutex.synchronize do
                    self.init if Process.pid != @process
                    if @buffer_size < MAX_LOG_BUFFER_SIZE
                        #Validate message
                        message = (message.nil? || message.to_s.strip.empty?) ? "EMPTY_STRING" : self.msg2str(message)
                        #Validate severity
                        severity = (severity.nil? || severity.to_s < Severity::DEBUG.to_s || severity.to_s > Severity::CRITICAL.to_s) ? Severity::DEBUG : severity

                        #Validate category
                        category = (category.nil? || category.to_s.strip.empty?) ? CORALOGIX_CATEGORY : category.to_s

                        #Combine a logentry from the must parameters together with the optional one.
                        new_entry = {:text => message, :timestamp => Time.now.utc.to_f * 1000 + @time_delta, :severity => severity, :category => category}.merge(args)
                        @buffer << new_entry
                        #Update the buffer size to reflect the new size.
                        @buffer_size+=new_entry.to_json.bytesize
                    end
                end
            rescue Exception => e  
                DebugLogger.error e.message  
                DebugLogger.error e.backtrace.inspect
                return false
            end
            return true
        end

        # Convert log message to string
        # @param msg    -   log message to convert
        #
        # @return [String] return log message as string
        def self.msg2str(msg)
            begin
                case msg
                    when ::String
                        msg
                    when ::Exception
                        "#{ msg.message } (#{ msg.class })\n" <<
                            (msg.backtrace || []).join("\n")
                    else
                        msg.inspect
                end
            rescue Exception => e
                DebugLogger.error e.message
                DebugLogger.error e.backtrace.inspect
                return msg
            end
        end
        
        # Flush all messages in buffer and send them immediately on the current thread.
        def self.flush
            self.send_bulk false
        end

        # Send bulk from the buffer
        def self.send_bulk time_sync=true
            begin
                self.update_time_delta_interval if time_sync
                @mutex.synchronize do
                    # Total buffer size
                    size = @buffer.size
                    return unless size > 0

                    # If the size is bigger than the maximum allowed chunk size then split it by half.
                    # Keep splitting it until the size is less than MAX_LOG_CHUNK_SIZE
                    while (@buffer.take(size).join(",").bytesize > MAX_LOG_CHUNK_SIZE) && (size > 0) 
                        size=size/2;
                    end
                    
                    # We must take at leat one value. If the first message is bigger than MAX_LOG_CHUNK_SIZE
                    # we need to take it anyway.
                    size = size > 0 ? size : 1

                    DebugLogger.info "Checking buffer size. Total log entries is: #{size}"
                    @bulk_template[:logEntries] = @buffer.shift(size)

                    # Extract from the buffer size the total amount of the logs we removed from the buffer
                    @buffer_size-= (@bulk_template[:logEntries].to_json.bytesize - 2 - size-1)

                    # Make sure we are always positive
                    @buffer_size = @buffer_size >= 0 ? @buffer_size : 0

                    DebugLogger.info "Bufer size after removal is: #{@buffer.join(",").bytesize}"
                end
                CoralogixHTTPSender.send_request(@bulk_template) unless @bulk_template[:logEntries].empty?
            rescue Exception => e  
                DebugLogger.error e.message  
                DebugLogger.error e.backtrace.inspect  
            end
        end

        # Sync log timestamps with coralogix server
        def self.update_time_delta_interval
            begin
                #If more than 5 seconds passed from the last sync update
                if ((DateTime.now.strftime('%Q').to_i - @time_delta_last_update) / 1000) >= (60 * SYNC_TIME_UPDATE_INTERVAL) #5 minuts
                    res, _time_delta = CoralogixHTTPSender.get_time_sync
                    if res
                        @time_delta = _time_delta
                        @time_delta_last_update = DateTime.now.strftime('%Q').to_i
                    end
                end
             rescue Exception => e  
                DebugLogger.error e.message  
                DebugLogger.error e.backtrace.inspect  
            end
        end

        # Spawn a new workter thread. [Obsolete]
        def self.reconnect
            #Backword compatibilty
        end

        # Start timer execution.
        # The timer should send every X seconds logs from the buffer.
        def self.run
            begin
                timer_thread = Thread.new do
                    while true
                        # Send log bulk
                        self.send_bulk

                        # Check when is the next time we should send logs?
                        # If we already have at least half of the max chunk size then we are working in fast mode
                        next_check_interval = @buffer_size > (MAX_LOG_CHUNK_SIZE / 2) ? FAST_SEND_SPEED_INTERVAL : NORMAL_SEND_SPEED_INTERVAL
                        DebugLogger.debug "Next buffer check is scheduled in #{next_check_interval} seconds"
                        sleep next_check_interval
                    end
                end

                #Set thread priority to a high number
                timer_thread.priority = 100
            rescue Exception => e  
                DebugLogger.error e.message  
                DebugLogger.error e.backtrace.inspect
                return false
            end
        end

        initialize
    end

end