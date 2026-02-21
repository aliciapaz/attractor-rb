# frozen_string_literal: true

RSpec.describe Attractor::Handlers::ConditionalHandler do
  subject(:handler) { described_class.new }

  let(:node) { Attractor::Node.new("gate", "shape" => "diamond", "label" => "Tests passing?") }
  let(:context) { Attractor::Context.new }
  let(:graph) { Attractor::Graph.new("test") }
  let(:logs_root) { Dir.mktmpdir }

  after { FileUtils.rm_rf(logs_root) }

  it "returns SUCCESS" do
    outcome = handler.execute(node, context, graph, logs_root)
    expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
  end

  it "includes the node id in notes" do
    outcome = handler.execute(node, context, graph, logs_root)
    expect(outcome.notes).to include("gate")
  end

  it "mentions conditional evaluation in notes" do
    outcome = handler.execute(node, context, graph, logs_root)
    expect(outcome.notes).to include("Conditional node evaluated")
  end
end
