# frozen_string_literal: true

RSpec.describe Attractor::Handlers::StartHandler do
  subject(:handler) { described_class.new }

  let(:node) { Attractor::Node.new("start", "shape" => "Mdiamond", "label" => "Start") }
  let(:context) { Attractor::Context.new }
  let(:graph) { Attractor::Graph.new("test") }
  let(:logs_root) { Dir.mktmpdir }

  after { FileUtils.rm_rf(logs_root) }

  it "returns SUCCESS" do
    outcome = handler.execute(node, context, graph, logs_root)
    expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
  end

  it "returns an Outcome" do
    outcome = handler.execute(node, context, graph, logs_root)
    expect(outcome).to be_a(Attractor::Outcome)
  end

  it "has no context_updates" do
    outcome = handler.execute(node, context, graph, logs_root)
    expect(outcome.context_updates).to be_empty
  end
end
