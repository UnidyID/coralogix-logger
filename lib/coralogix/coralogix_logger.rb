require_relative 'manager'
require_relative 'debug_logger'
require_relative 'httpsender'
require_relative 'constants'

module Coralogix

    class CoralogixLogger

        attr_accessor :use_source_file
        # Set 'new' method to be a private method. 
        # This way it won't be possible to create a new intance of this class from outside.
        private_class_method :new
        @@print_stack_trace = false
        @@stack_frame = 5
        # Constructor. 
        #
        # @param name    -   logger name.
        def initialize name
            @category = name
            @level=0
            @use_source_file = true
        end

        # Logger interface:  
        # Set Logger level
        #
        # @param name   -   level
        def level= level
            @level=level
        end

        # A getter for debug_mode. 
        # Default value is false.
        # When set to true the coralogix logger will print output messages to a console and a file.
        #
        # @return [boolean]    -   true or false. (Default is false)
        def self.debug_mode?
            DebugLogger.debug_mode
        end

        # A setter for debug_mode. 
        # Default value is false.
        # When set to true the coralogix logger will print output messages to a console and a file.
        #
        # @param value    -   true or false. (Default is false)
        def self.debug_mode=(value)
            DebugLogger.debug_mode=value
        end

        # A setter for print stack trace. 
        # Default value is false.
        # When set to true the coralogix logger will print stack trace for each log line.
        #
        # @param value    -   true or false. (Default is false)
        def self.print_stack_trace=(value)
            @@print_stack_trace=value
        end

        # A setter for stack frame. 
        # Default value is 5.
        # The stack frame to extract from the stack trace
        #
        # @param value [int]   -  (Default is 5)
        def self.stack_frame=(value)
            @@stack_frame=value
        end


        # A setter for disable_proxy. 
        # By default HTTP object will use proxy environment variable if exists. In some cases this migh be an issue
        # When set to false the HTTP object will ignore any proxy.
        #
        # @param value    -   true or false. (Default is false)
        def self.disable_proxy=(value)
            CoralogixHTTPSender.disable_proxy=value
        end

        # A class method (static) to return a new instance of the current class.
        # This is the most common pattern when using logging.
        #
        # @param name    -   name of the logger. The category. Usually this will be a new name for every class or a logical unit.
        # @return [CoralogixLogger] return a new instance of CoralogixLogger.
        def self.get_logger name
            #Return a new instance of the current class.
            CoralogixLogger.send(:new, name)
        end

        # Configure coralogix logger with customer specific values
        #
        # @param private_key    -   private key
        # @param app_name       -   application name
        # @param sub_system     -   sub system name
        # @return [boolean] return a true or false.
        def self.configure private_key, app_name, sub_system
            private_key = (private_key.nil? || private_key.to_s.strip.empty?) ? FAILED_PRIVATE_KEY : private_key
            app_name = (app_name.nil? || app_name.to_s.strip.empty?) ? NO_APP_NAME : app_name
            sub_system = (sub_system.nil? || sub_system.to_s.strip.empty?) ? NO_SUB_SYSTEM : sub_system
            LoggerManager.configure(:privateKey => private_key, :applicationName => app_name, :subsystemName => sub_system) unless LoggerManager.configured
        end

        # Spawn a new worker thread
        def self.reconnect
            LoggerManager.reconnect
        end


        # Flush all messages in buffer and send them immediately on the current thread.
        def flush
            LoggerManager.flush
        end


        # Log a message. 
        #
        # @param severity    -   log severity
        # @param message     -   log message
        # @param category    -   log category
        # @param className   -   log class name
        # @param methodName  -   log method name
        # @param threadId    -   log thread id
        def log severity, message, category: @category, className: "", methodName: "", threadId: Thread.current.object_id.to_s
            LoggerManager.add_logline message, severity, category, :className => className, :methodName => methodName, :threadId => threadId
        end 

        # Create log methods for each severity. 
        # This is a ruby thing. If you are writing in other languages just create a method for each severity.
        # For instance, for info severity it will create a method:
        # def info message, category: @category, className: "", methodName: "", threadId: ""
        SEVERITIES.keys.each do |severity|
            define_method("#{severity}") do |message, category: @category, className: "", methodName: "", threadId: Thread.current.object_id.to_s|
                LoggerManager.add_logline message, SEVERITIES["#{__method__}".to_sym], category, :className => className, :methodName => methodName, :threadId => threadId
            end  
        end

        # Logger interface: 
        # Send log message if the given severity is high enough.
        # @param severity   -   Severity.  Constants are defined in Logger namespace: +DEBUG+, +INFO+, +WARN+, +ERROR+, +FATAL+, or +UNKNOWN
        # @param message   -   The log message.  A String or Exception.
        # @param progname   -   Program name string.  Can be omitted.  Treated as a message if no +message+ and +block+ are given.
        # @param block   -   Can be omitted.  Called to get a message string if +message+ is nil.
        # @return [boolean] When the given severity is not high enough (for this particular logger), log no message, and return true.
        def add(severity, message = nil, progname = nil, &block)
            
            thread = ""

            begin
                severity ||= DEBUG
                if severity < @level
                    return true
                end
                progname ||= @category
                if message.nil?
                    if block_given?
                        message = yield
                    else
                        message = progname
                        progname = @category
                    end
                end
                className = get_source_file if @use_source_file
                thread = Thread.current.object_id.to_s
            rescue Exception => e  
                DebugLogger.error e.message  
                DebugLogger.error e.backtrace.inspect
            end

            # Map Ruby Severity to Coralogix severity:
            #          Ruby Coralogix
            #    DEBUG  0      1
            #    INFO   1      3
            #    WARN   2      4
            #    ERROR  3      5
            #    FATAL  4      6
            LoggerManager.add_logline message, severity == 0 ? Severity::DEBUG : severity + 2, progname, :className => className, :threadId => thread
        end

        # Logger interface: 
        # Dump given message to the log device without any formatting.  
        def << x
            self.add 0, nil, x
        end

        # Logger interface: 
        # Set logger program name. This will be used as the category.
        def progname= name
            @category = name
        end

        # Logger interface:
        # Set logger formatter
        def formatter= formatter
            # Nothing to do here as we always use Coralogix format
        end

        # Logger interface: 
        # Close coralogix logger. Not implemented
        def close
            # Not implemented
        end

        # Return the file name where the call to the logger was made. This will be used as the class name
        def get_source_file
            begin
                #        0                          1                               2                   3
                #logger.info(Rails logger) -> Logger.broadcast(Rails Logger)-> add(This class) -> get_source_file(This method)
                if  DebugLogger.debug_mode? && @@print_stack_trace
                    DebugLogger.info "Stack trace:"
                    DebugLogger.info caller_locations(0..10).join("\n")
                end
                
                file_location_path = caller_locations(@@stack_frame..@@stack_frame)[0].path
                File.basename(file_location_path, File.extname(file_location_path))
            rescue Exception => e  
                DebugLogger.error e.message  
                DebugLogger.error e.backtrace.inspect
                return nil
            end
        end
    end

end
