# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::Checkpoint do
  let(:tmpdir) { Dir.mktmpdir("attractor-checkpoint-test") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#save and .load" do
    it "round-trips all fields through JSON serialization" do
      checkpoint = described_class.new(
        current_node: "implement",
        completed_nodes: %w[start plan implement],
        node_retries: {"implement" => 2},
        context_values: {"graph.goal" => "Build feature", "outcome" => "success"},
        logs: ["Started pipeline", "Plan completed"]
      )

      path = File.join(tmpdir, "checkpoint.json")
      checkpoint.save(path)
      loaded = described_class.load(path)

      expect(loaded.current_node).to eq("implement")
      expect(loaded.completed_nodes).to eq(%w[start plan implement])
      expect(loaded.node_retries).to eq({"implement" => 2})
      expect(loaded.context_values).to eq({"graph.goal" => "Build feature", "outcome" => "success"})
      expect(loaded.logs).to eq(["Started pipeline", "Plan completed"])
    end

    it "saves valid JSON to disk" do
      checkpoint = described_class.new(
        current_node: "A",
        completed_nodes: ["A"],
        context_values: {"key" => "value"}
      )

      path = File.join(tmpdir, "checkpoint.json")
      checkpoint.save(path)

      data = JSON.parse(File.read(path))
      expect(data["current_node"]).to eq("A")
      expect(data["completed_nodes"]).to eq(["A"])
      expect(data["context"]["key"]).to eq("value")
    end

    it "creates intermediate directories if needed" do
      checkpoint = described_class.new(current_node: "A")
      path = File.join(tmpdir, "nested", "dir", "checkpoint.json")

      checkpoint.save(path)

      expect(File.exist?(path)).to be true
    end
  end

  describe ".exists?" do
    it "returns true when checkpoint file exists" do
      checkpoint = described_class.new(current_node: "A")
      checkpoint.save(described_class.checkpoint_path(tmpdir))

      expect(described_class.exists?(tmpdir)).to be true
    end

    it "returns false when checkpoint file does not exist" do
      expect(described_class.exists?(tmpdir)).to be false
    end
  end

  describe ".checkpoint_path" do
    it "returns the expected path" do
      expect(described_class.checkpoint_path("/logs")).to eq("/logs/checkpoint.json")
    end
  end
end
