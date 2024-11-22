require 'logger'

module Coralogix
    # @private
    class DebugLogger

        def self.initialize
            begin
                @mutex = Mutex.new
                @debug = false
            rescue Exception => e
                if @debug  
                    puts e.message  
                    puts e.backtrace.inspect  
                end
            end
        end 

        def self.debug_mode?
            @debug
        end

        def self.debug_mode=(value)
            begin
                @debug = value
                if value
                    @logger = Logger.new(LOG_FILE_NAME, 1, 10485760)
                else
                    @logger.close unless @logger == nil
                    @logger = nil
                end
            rescue Exception => e
                if @debug  
                    puts e.message  
                    puts e.backtrace.inspect  
                end
            end
        end

        Logger::Severity.constants.each do |level|
            define_singleton_method("#{level.downcase}") do |*args|
                if @debug
                    @mutex.synchronize do
                        begin
                            puts "#{__method__.upcase}:  #{Time.now.strftime('%H:%M:%S.%L')} - #{args}"
                            @logger.send("#{__method__}", args)
                        rescue Exception => e
                            puts e.message  
                            puts e.backtrace.inspect  
                        end
                    end
                end
            end  
        end


        initialize
    
    end

end