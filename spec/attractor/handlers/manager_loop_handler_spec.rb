# frozen_string_literal: true

RSpec.describe Attractor::Handlers::ManagerLoopHandler do
  subject(:handler) { described_class.new }

  let(:context) { Attractor::Context.new }
  let(:graph) { Attractor::Graph.new("test") }
  let(:logs_root) { Dir.mktmpdir }

  after { FileUtils.rm_rf(logs_root) }

  def make_node(attrs = {})
    defaults = {
      "shape" => "house",
      "manager.poll_interval" => 0,
      "manager.max_cycles" => 5
    }
    Attractor::Node.new("manager", defaults.merge(attrs))
  end

  describe "when child completes successfully" do
    it "returns SUCCESS" do
      context.set("context.stack.child.status", "completed")
      context.set("context.stack.child.outcome", "success")
      node = make_node

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
    end

    it "reports the cycle count" do
      context.set("context.stack.child.status", "completed")
      context.set("context.stack.child.outcome", "success")
      node = make_node

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.context_updates["manager.cycles_completed"]).to eq(1)
      expect(outcome.notes).to include("cycle 1")
    end
  end

  describe "when child fails" do
    it "returns FAIL" do
      context.set("context.stack.child.status", "failed")
      node = make_node

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
      expect(outcome.failure_reason).to include("Child failed")
    end
  end

  describe "when max cycles exceeded" do
    it "returns FAIL after exhausting cycles" do
      node = make_node("manager.max_cycles" => 3)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
      expect(outcome.failure_reason).to include("Max cycles (3)")
      expect(outcome.context_updates["manager.cycles_completed"]).to eq(3)
    end
  end

  describe "with a stop condition" do
    it "returns SUCCESS when stop condition is satisfied" do
      context.set("build.status", "done")
      node = make_node("manager.stop_condition" => 'build.status="done"')

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
      expect(outcome.notes).to include("Stop condition satisfied")
    end

    it "continues polling when stop condition is not satisfied" do
      context.set("build.status", "running")
      node = make_node(
        "manager.stop_condition" => 'build.status="done"',
        "manager.max_cycles" => 2
      )

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
      expect(outcome.failure_reason).to include("Max cycles")
    end
  end

  describe "poll interval parsing" do
    it "does not error when poll_interval is not specified" do
      # Set child to succeed immediately so we don't hit the default 45s sleep
      context.set("context.stack.child.status", "completed")
      context.set("context.stack.child.outcome", "success")
      node = Attractor::Node.new("manager", "shape" => "house", "manager.max_cycles" => 1)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
    end
  end
end
