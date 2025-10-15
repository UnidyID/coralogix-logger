# frozen_string_literal: true

require "spec_helper"

RSpec.describe Coralogix do
  it "has a version number" do
    expect(Coralogix::VERSION).not_to be nil
  end
end

RSpec.describe Coralogix::Logger do
  subject(:logger) { Coralogix.get_logger("test-category") }

  # Before each test, configure the SDK and mock the internal Manager
  # to prevent actual network calls and isolate the Logger class.
  before do
    # Use the public API to configure the logger
    Coralogix.configure("test_key", "test_app", "test_subsystem", ssl_verify_peer: false)

    # Mock the singleton instance of the Manager
    allow(Coralogix::Manager.instance).to receive(:add_logline)
  end

  describe "Rails 8 compatibility" do
    it "responds to #formatter= without error" do
      # This test confirms compatibility with Rails 8's BroadcastLogger.
      # Our implementation intentionally makes this a no-op, but the method must exist.
      expect { logger.formatter = proc {} }.not_to raise_error
    end
  end

  describe "logging messages" do
    it "sends a string log to the Manager as a JSON object" do
      logger.info("test message")

      expect(Coralogix::Manager.instance).to have_received(:add_logline).with(
        '{"message":"test message"}',
        Coralogix::Severity::INFO,
        "test-category",
        hash_including(className: anything, threadId: anything)
      )
    end

    it "sends a hash log to the Manager as JSON" do
      logger.warn({ key: "value" })

      expect(Coralogix::Manager.instance).to have_received(:add_logline).with(
        '{"key":"value"}',
        Coralogix::Severity::WARNING,
        "test-category",
        hash_including(className: anything, threadId: anything)
      )
    end

    it "does not send a log if the level is too low" do
      logger.level = Coralogix::Logger::WARN # Set level to WARN
      logger.info("this should not be logged")

      expect(Coralogix::Manager.instance).not_to have_received(:add_logline)
    end
  end

  describe "#close" do
    it "flushes the manager" do
      allow(Coralogix::Manager.instance).to receive(:flush)
      logger.close
      expect(Coralogix::Manager.instance).to have_received(:flush)
    end
  end
end
