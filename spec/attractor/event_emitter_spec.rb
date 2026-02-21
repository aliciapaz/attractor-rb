# frozen_string_literal: true

RSpec.describe Attractor::EventEmitter do
  subject(:emitter) { described_class.new }

  describe "#emit" do
    it "calls all registered listeners" do
      events = []
      emitter.on_event { |e| events << e }
      emitter.on_event { |e| events << e }

      emitter.emit("test_event")

      expect(events).to eq(%w[test_event test_event])
    end

    it "continues notifying remaining listeners when one raises" do
      events = []
      emitter.on_event { raise "boom" }
      emitter.on_event { |e| events << e }

      emitter.emit("test_event")

      expect(events).to eq(["test_event"])
    end

    it "prints a warning when a listener raises" do
      emitter.on_event { raise "boom" }

      expect { emitter.emit("test_event") }.to output(/EventEmitter: listener raised.*boom/).to_stderr
    end
  end
end
