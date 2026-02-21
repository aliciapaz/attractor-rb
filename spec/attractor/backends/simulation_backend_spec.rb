# frozen_string_literal: true

RSpec.describe Attractor::Backends::SimulationBackend do
  subject(:backend) { described_class.new }

  let(:node) { Attractor::Node.new("plan", "shape" => "box", "label" => "Plan") }
  let(:context) { Attractor::Context.new }

  describe "#run" do
    it "returns a string response" do
      result = backend.run(node, "Plan the feature", context)
      expect(result).to be_a(String)
    end

    it "includes the node id in the response" do
      result = backend.run(node, "Plan the feature", context)
      expect(result).to include("plan")
    end

    it "includes [Simulated] prefix" do
      result = backend.run(node, "Plan the feature", context)
      expect(result).to eq("[Simulated] Response for: plan")
    end

    it "returns different responses for different nodes" do
      other_node = Attractor::Node.new("implement", "shape" => "box", "label" => "Implement")
      result_plan = backend.run(node, "Plan", context)
      result_impl = backend.run(other_node, "Implement", context)
      expect(result_plan).not_to eq(result_impl)
    end
  end
end
