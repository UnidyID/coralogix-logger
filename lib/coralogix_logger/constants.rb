# frozen_string_literal: true

module Coralogix
  # Maximum log buffer size
  MAX_LOG_BUFFER_SIZE = 12_582_912 # 12mb

  # Maximum chunk size
  MAX_LOG_CHUNK_SIZE = 1_572_864 # 1.5 mb

  # Bulk send interval in normal mode.
  NORMAL_SEND_SPEED_INTERVAL = 0.5 # 500ms

  # Bulk send interval in fast mode.
  FAST_SEND_SPEED_INTERVAL = 0.1 # 100ms

  # Coralogix logs url
  CORALOGIX_LOG_URL = ENV.fetch("CORALOGIX_LOG_URL", "https://ingress.eu2.coralogix.com/logs/v1/singles").freeze

  # Default application name
  DEFAULT_APP_NAME = "DEFAULT_APP_NAME"

  # Default subsystem name
  DEFAULT_SUB_SYSTEM = "NO_SUB_NAME"

  # Default log file name
  LOG_FILE_NAME = "coralogix.sdk.log"

  # Default http timeout
  HTTP_TIMEOUT = 30

  # Number of attempts to retry http post
  HTTP_SEND_RETRY_COUNT = 5

  # Interval between failed http post requests
  HTTP_SEND_RETRY_INTERVAL = 2

  # Coralogix category
  CORALOGIX_CATEGORY = "CORALOGIX"

  module Severity
    DEBUG = 1
    VERBOSE = 2
    INFO = 3
    WARNING = 4
    ERROR = 5
    CRITICAL = 6
  end
end
