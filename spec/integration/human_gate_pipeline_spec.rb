# frozen_string_literal: true

RSpec.describe "Human gate pipeline integration" do
  let(:logs_root) { Dir.mktmpdir("attractor-test-") }

  after { FileUtils.rm_rf(logs_root) }

  let(:dot_source) do
    <<~DOT
      digraph Review {
          start [shape=Mdiamond, label="Start"]
          exit  [shape=Msquare, label="Exit"]

          review_gate [
              shape=hexagon,
              label="Review Changes",
              type="wait.human"
          ]

          ship_it [shape=box, prompt="Ship the changes"]
          fixes   [shape=box, prompt="Apply fixes"]

          start -> review_gate
          review_gate -> ship_it [label="[A] Approve"]
          review_gate -> fixes   [label="[F] Fix"]
          ship_it -> exit
          fixes -> exit
      }
    DOT
  end

  it "routes to the approved option via queue interviewer" do
    approve_answer = Attractor::Answer.new(
      value: "A",
      selected_option: Attractor::Option.new(key: "A", label: "[A] Approve")
    )
    interviewer = Attractor::Interviewer::Queue.new(answers: [approve_answer])
    backend = Attractor::Backends::SimulationBackend.new
    engine = Attractor::Engine.new(backend: backend, interviewer: interviewer)

    outcome = engine.run(dot_source, logs_root: logs_root)
    expect(outcome).to be_success

    checkpoint = Attractor::Checkpoint.load(
      Attractor::Checkpoint.checkpoint_path(logs_root)
    )
    expect(checkpoint.completed_nodes).to include("review_gate", "ship_it")
    expect(checkpoint.completed_nodes).not_to include("fixes")
  end

  it "routes to the fix option when selected" do
    fix_answer = Attractor::Answer.new(
      value: "F",
      selected_option: Attractor::Option.new(key: "F", label: "[F] Fix")
    )
    interviewer = Attractor::Interviewer::Queue.new(answers: [fix_answer])
    backend = Attractor::Backends::SimulationBackend.new
    engine = Attractor::Engine.new(backend: backend, interviewer: interviewer)

    outcome = engine.run(dot_source, logs_root: logs_root)
    expect(outcome).to be_success

    checkpoint = Attractor::Checkpoint.load(
      Attractor::Checkpoint.checkpoint_path(logs_root)
    )
    expect(checkpoint.completed_nodes).to include("review_gate", "fixes")
    expect(checkpoint.completed_nodes).not_to include("ship_it")
  end

  it "auto-approves with AutoApprove interviewer" do
    interviewer = Attractor::Interviewer::AutoApprove.new
    backend = Attractor::Backends::SimulationBackend.new
    engine = Attractor::Engine.new(backend: backend, interviewer: interviewer)

    outcome = engine.run(dot_source, logs_root: logs_root)
    expect(outcome).to be_success
  end
end
