# frozen_string_literal: true

RSpec.describe "Branching pipeline integration" do
  let(:logs_root) { Dir.mktmpdir("attractor-test-") }

  after { FileUtils.rm_rf(logs_root) }

  let(:dot_source) do
    <<~DOT
      digraph Branch {
          graph [goal="Implement and validate a feature"]
          node [shape=box]

          start     [shape=Mdiamond, label="Start"]
          exit      [shape=Msquare, label="Exit"]
          plan      [label="Plan", prompt="Plan the implementation"]
          implement [label="Implement", prompt="Implement the plan", goal_gate=true]
          validate  [label="Validate", prompt="Run tests"]
          gate      [shape=diamond, label="Tests passing?"]

          start -> plan -> implement -> validate -> gate
          gate -> exit      [label="Yes", condition="outcome=success"]
          gate -> implement [label="No", condition="outcome!=success"]
      }
    DOT
  end

  it "follows the success path through conditional edges" do
    backend = Attractor::Backends::SimulationBackend.new
    engine = Attractor::Engine.new(backend: backend)
    outcome = engine.run(dot_source, logs_root: logs_root)

    expect(outcome).to be_success

    checkpoint = Attractor::Checkpoint.load(
      Attractor::Checkpoint.checkpoint_path(logs_root)
    )
    expect(checkpoint.completed_nodes).to include("plan", "implement", "validate", "gate")
  end

  context "with goal gate enforcement" do
    let(:dot_with_retry) do
      <<~DOT
        digraph GoalGate {
            graph [goal="Test goal gates", retry_target="plan"]

            start     [shape=Mdiamond]
            exit      [shape=Msquare]
            plan      [shape=box, prompt="Plan"]
            critical  [shape=box, prompt="Critical task", goal_gate=true]

            start -> plan -> critical -> exit
        }
      DOT
    end

    it "allows exit when goal gates are satisfied" do
      backend = Attractor::Backends::SimulationBackend.new
      engine = Attractor::Engine.new(backend: backend)
      outcome = engine.run(dot_with_retry, logs_root: logs_root)

      expect(outcome).to be_success
    end
  end

  context "with conditional routing on outcome" do
    it "routes based on edge conditions matching context" do
      backend = Attractor::Backends::SimulationBackend.new
      engine = Attractor::Engine.new(backend: backend)

      events = []
      engine.event_emitter.on_event { |e| events << e }

      engine.run(dot_source, logs_root: logs_root)

      completed_names = events
        .select { |e| e.is_a?(Attractor::Events::StageCompleted) }
        .map(&:name)

      # Simulation backend returns SUCCESS, so gate should route to exit
      expect(completed_names).to include("gate")
    end
  end
end
