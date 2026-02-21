# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::Engine do
  let(:logs_root) { Dir.mktmpdir("attractor-engine-test") }

  after do
    FileUtils.rm_rf(logs_root)
  end

  def simple_linear_dot
    <<~DOT
      digraph Simple {
        graph [goal="Run tests"]
        start [shape=Mdiamond, label="Start"]
        run_tests [shape=box, label="Run Tests", prompt="Run tests"]
        report [shape=box, label="Report", prompt="Report results"]
        exit [shape=Msquare, label="Exit"]

        start -> run_tests -> report -> exit
      }
    DOT
  end

  def branching_dot
    <<~DOT
      digraph Branch {
        graph [goal="Branch test"]
        start [shape=Mdiamond]
        exit [shape=Msquare]
        gate [shape=diamond, label="Check"]
        node_a [shape=box, label="Path A", prompt="A"]
        node_b [shape=box, label="Path B", prompt="B"]

        start -> gate
        gate -> node_a [weight=5]
        gate -> node_b [weight=1]
        node_a -> exit
        node_b -> exit
      }
    DOT
  end

  describe "#run" do
    context "with a linear pipeline" do
      it "traverses all nodes from start to exit" do
        backend = Attractor::Backends::SimulationBackend.new
        engine = described_class.new(backend: backend)

        outcome = engine.run(simple_linear_dot, logs_root: logs_root)

        expect(outcome).not_to be_nil
        expect(outcome.success?).to be true
      end

      it "writes checkpoint and manifest files" do
        backend = Attractor::Backends::SimulationBackend.new
        engine = described_class.new(backend: backend)

        engine.run(simple_linear_dot, logs_root: logs_root)

        expect(File.exist?(File.join(logs_root, "manifest.json"))).to be true
        expect(File.exist?(File.join(logs_root, "checkpoint.json"))).to be true
      end

      it "writes status files for each node" do
        backend = Attractor::Backends::SimulationBackend.new
        engine = described_class.new(backend: backend)

        engine.run(simple_linear_dot, logs_root: logs_root)

        expect(File.exist?(File.join(logs_root, "start", "status.json"))).to be true
        expect(File.exist?(File.join(logs_root, "run_tests", "status.json"))).to be true
        expect(File.exist?(File.join(logs_root, "report", "status.json"))).to be true
        expect(File.exist?(File.join(logs_root, "exit", "status.json"))).to be true
      end
    end

    context "with context propagation" do
      it "sets graph.goal in context" do
        backend = Attractor::Backends::SimulationBackend.new
        engine = described_class.new(backend: backend)

        engine.event_emitter.on_event do |event|
          if event.is_a?(Attractor::Events::PipelineCompleted)
            # The pipeline completed successfully
          end
        end

        engine.run(simple_linear_dot, logs_root: logs_root)

        checkpoint = Attractor::Checkpoint.load(Attractor::Checkpoint.checkpoint_path(logs_root))
        expect(checkpoint.context_values["graph.goal"]).to eq("Run tests")
      end

      it "records outcome status in context" do
        backend = Attractor::Backends::SimulationBackend.new
        engine = described_class.new(backend: backend)

        engine.run(simple_linear_dot, logs_root: logs_root)

        checkpoint = Attractor::Checkpoint.load(Attractor::Checkpoint.checkpoint_path(logs_root))
        expect(checkpoint.context_values["outcome"]).to eq(Attractor::StageStatus::SUCCESS)
      end
    end

    context "with branching" do
      it "selects the highest-weight edge from a conditional node" do
        backend = Attractor::Backends::SimulationBackend.new
        engine = described_class.new(backend: backend)

        outcome = engine.run(branching_dot, logs_root: logs_root)

        expect(outcome.success?).to be true

        checkpoint = Attractor::Checkpoint.load(Attractor::Checkpoint.checkpoint_path(logs_root))
        expect(checkpoint.completed_nodes).to include("node_a")
        expect(checkpoint.completed_nodes).not_to include("node_b")
      end
    end

    context "with events" do
      it "emits PipelineStarted and PipelineCompleted events" do
        backend = Attractor::Backends::SimulationBackend.new
        emitter = Attractor::EventEmitter.new
        events = []
        emitter.on_event { |e| events << e }

        engine = described_class.new(backend: backend, event_emitter: emitter)
        engine.run(simple_linear_dot, logs_root: logs_root)

        event_types = events.map(&:class)
        expect(event_types).to include(Attractor::Events::PipelineStarted)
        expect(event_types).to include(Attractor::Events::PipelineCompleted)
      end

      it "emits StageStarted and StageCompleted events" do
        backend = Attractor::Backends::SimulationBackend.new
        emitter = Attractor::EventEmitter.new
        events = []
        emitter.on_event { |e| events << e }

        engine = described_class.new(backend: backend, event_emitter: emitter)
        engine.run(simple_linear_dot, logs_root: logs_root)

        started_events = events.select { |e| e.is_a?(Attractor::Events::StageStarted) }
        completed_events = events.select { |e| e.is_a?(Attractor::Events::StageCompleted) }

        expect(started_events.map(&:name)).to include("start", "run_tests", "report")
        expect(completed_events.map(&:name)).to include("start", "run_tests", "report")
      end
    end

    context "with a Graph object instead of DOT source" do
      it "accepts a pre-parsed Graph" do
        start_node = Attractor::Node.new("start", "shape" => "Mdiamond")
        exit_node = Attractor::Node.new("exit", "shape" => "Msquare")
        graph = Attractor::Graph.new(
          "test",
          nodes: {"start" => start_node, "exit" => exit_node},
          edges: [Attractor::Edge.new("start", "exit")],
          attrs: {"goal" => "test"}
        )

        backend = Attractor::Backends::SimulationBackend.new
        engine = described_class.new(backend: backend)

        outcome = engine.run(graph, logs_root: logs_root)

        expect(outcome.success?).to be true
      end
    end
  end
end
