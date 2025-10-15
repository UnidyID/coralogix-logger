# frozen_string_literal: true

require "spec_helper"

# This spec file acts as an integration test to ensure the final payload
# sent to the HTTP sender conforms to the Coralogix API specification.
RSpec.describe Coralogix::Manager do
  let(:http_sender_double) { instance_double(Coralogix::HttpSender, send_request: true) }

  before do
    # Reset the singleton instance before each test to ensure a clean state.
    # This is crucial for testing singletons.
    Singleton.send(:__init__, Coralogix::Manager)

    # Mock the HttpSender to prevent actual network calls and to capture its input.
    allow(Coralogix::HttpSender).to receive(:new).and_return(http_sender_double)
  end

  it "sends a payload conforming to the Coralogix API schema" do
    # 1. Configure the SDK using the public API
    Coralogix.configure("test_key", "my_app", "my_subsystem")

    # 2. Create a logger and log a message
    logger = Coralogix.get_logger("my_category")
    logger.info("hello world")

    # 3. Flush the buffer to trigger the send mechanism
    Coralogix.flush

    # 4. Assert that the HttpSender was called with a correctly formatted payload
    expect(http_sender_double).to have_received(:send_request) do |json_payload|
      # The payload must be a JSON array string
      payload = JSON.parse(json_payload)
      expect(payload).to be_an(Array)

      # The buffer contains only our test log.
      log_entry = payload.first
      expect(log_entry).to be_a(Hash)

      # Assert against the required and optional fields from the API documentation
      expect(log_entry["applicationName"]).to eq("my_app")
      expect(log_entry["subsystemName"]).to eq("my_subsystem")
      expect(log_entry["computerName"]).to be_a(String) # Should be the hostname
      expect(log_entry["timestamp"]).to be_a(Numeric)   # Should be UTC milliseconds
      expect(log_entry["severity"]).to eq(Coralogix::Severity::INFO)
      expect(log_entry["category"]).to eq("my_category")

      # Assert that the text payload is itself a JSON object string
      text_payload = JSON.parse(log_entry["text"])
      expect(text_payload).to eq({ "message" => "hello world" })
    end
  end
end
