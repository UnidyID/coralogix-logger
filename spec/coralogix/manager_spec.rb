# frozen_string_literal: true

require "spec_helper"

# This spec file acts as an integration test to ensure the final payload
# sent to the HTTP sender conforms to the Coralogix API specification.
RSpec.describe Coralogix::Manager do
  let(:captured_payloads) { [] }
  let(:http_sender_double) do
    instance_double(Coralogix::HttpSender).tap do |sender|
      allow(sender).to receive(:send_request) { |json| captured_payloads << json }
    end
  end
  let(:payload) do
    Coralogix.configure("test_key", "my_app", "my_subsystem")
    Coralogix.get_logger("my_category").info("hello world")
    Coralogix.flush
    JSON.parse(captured_payloads.last)
  end

  before do
    # Reset the singleton instance before each test to ensure a clean state.
    Singleton.send(:__init__, described_class)

    # Mock the HttpSender to prevent actual network calls and to capture its input.
    allow(Coralogix::HttpSender).to receive(:new).and_return(http_sender_double)
  end

  it "sends a payload as a JSON array with startup message and log entry", :aggregate_failures do
    expect(payload).to be_an(Array)
    expect(payload.size).to eq(2)
  end

  describe "startup message" do
    subject(:startup_entry) { payload[0] }

    it "includes the startup message with correct category and text", :aggregate_failures do
      expect(startup_entry["category"]).to eq("CORALOGIX")
      expect(startup_entry["text"]).to include("has started to send data")
    end
  end

  describe "log entry" do
    subject(:log_entry) { payload[1] }

    it "includes application metadata", :aggregate_failures do
      expect(log_entry["applicationName"]).to eq("my_app")
      expect(log_entry["subsystemName"]).to eq("my_subsystem")
      expect(log_entry["computerName"]).to be_a(String)
    end

    it "includes timestamp and severity", :aggregate_failures do
      expect(log_entry["timestamp"]).to be_a(Numeric)
      expect(log_entry["severity"]).to eq(Coralogix::Severity::INFO)
    end

    it "includes the logger category" do
      expect(log_entry["category"]).to eq("my_category")
    end

    it "includes the message as a JSON object in text field" do
      text_payload = JSON.parse(log_entry["text"])
      expect(text_payload).to eq({ "message" => "hello world" })
    end
  end
end
