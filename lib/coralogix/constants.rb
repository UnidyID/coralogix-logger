module Coralogix

    #Maximum log buffer size
    MAX_LOG_BUFFER_SIZE = 12582912 #12mb

    #Maximum chunk size
    MAX_LOG_CHUNK_SIZE = 1572864 #1.5 mb

    #Bulk send interval in normal mode.
    NORMAL_SEND_SPEED_INTERVAL = 500.0 / 1000

    #Bulk send interval in fast mode.
    FAST_SEND_SPEED_INTERVAL = 100.0 / 1000

    #Corologix severity mapper
    SEVERITIES = {:debug => 1, :verbose => 2, :info => 3, :warning => 4, :warn => 4, :error => 5, :fatal =>5, :critical => 6}


    module Severity
        DEBUG = 1
        VERBOSE = 2
        INFO = 3
        WARNING = 4
        ERROR = 5
        CRITICAL = 6
    end


    #Coralogix logs url
    CORALOGIX_LOG_URL =  ENV['CORALOGIX_LOG_URL'].nil? ? "https://api.coralogix.com:443/api/v1/logs" : "https://api."+ENV['CORALOGIX_LOG_URL']+"/api/v1/logs"
    #Coralogix time delat url
    CORALOGIX_TIME_DELTA_URL = ENV['CORALOGIX_LOG_URL'].nil? ? "https://api.coralogix.com:443/api/v1/logs" : "https://api."+ENV['CORALOGIX_LOG_URL']+"/api/v1/logs"
    #Default private key
    FAILED_PRIVATE_KEY = "9626c7dd-8174-5015-a3fe-5572e042b6d9"

    #Default application name
    NO_APP_NAME = "NO_APP_NAME"

    #Default subsystem name
    NO_SUB_SYSTEM = "NO_SUB_NAME"

    #Default log file name
    LOG_FILE_NAME = "coralogix.sdk.log"

    #Default http timeout
    HTTP_TIMEOUT = 30

    #Number of attempts to retry http post
    HTTP_SEND_RETRY_COUNT = 5

    #Interval between failed http post requests
    HTTP_SEND_RETRY_INTERVAL = 2

    # Coralogix category
    CORALOGIX_CATEGORY = 'CORALOGIX'

    # Sync time update interval
    SYNC_TIME_UPDATE_INTERVAL = 5 #minutes

end
