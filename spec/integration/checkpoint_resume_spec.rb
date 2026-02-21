# frozen_string_literal: true

RSpec.describe "Checkpoint resume integration" do
  let(:logs_root) { Dir.mktmpdir("attractor-test-") }

  after { FileUtils.rm_rf(logs_root) }

  let(:dot_source) do
    <<~DOT
      digraph Resume {
          graph [goal="Test checkpoint resume"]

          start  [shape=Mdiamond, label="Start"]
          exit   [shape=Msquare, label="Exit"]
          step_a [shape=box, prompt="Step A"]
          step_b [shape=box, prompt="Step B"]
          step_c [shape=box, prompt="Step C"]

          start -> step_a -> step_b -> step_c -> exit
      }
    DOT
  end

  it "saves checkpoint after each node" do
    backend = Attractor::Backends::SimulationBackend.new
    engine = Attractor::Engine.new(backend: backend)
    engine.run(dot_source, logs_root: logs_root)

    checkpoint = Attractor::Checkpoint.load(
      Attractor::Checkpoint.checkpoint_path(logs_root)
    )
    expect(checkpoint.completed_nodes).to include("start", "step_a", "step_b", "step_c", "exit")
  end

  it "resumes from checkpoint and completes remaining nodes" do
    # Simulate a partial run by creating a checkpoint mid-pipeline
    graph = Attractor::Dot::Parser.parse(dot_source)

    partial_checkpoint = Attractor::Checkpoint.new(
      current_node: "step_b",
      completed_nodes: %w[start step_a step_b],
      node_retries: {},
      context_values: {
        "graph.goal" => "Test checkpoint resume",
        "outcome" => "success",
        "last_stage" => "step_b"
      },
      logs: []
    )
    FileUtils.mkdir_p(logs_root)
    partial_checkpoint.save(Attractor::Checkpoint.checkpoint_path(logs_root))

    # Write manifest so engine doesn't fail
    Attractor::RunDirectory.write_manifest(logs_root, graph)

    # Resume execution
    backend = Attractor::Backends::SimulationBackend.new
    engine = Attractor::Engine.new(backend: backend)
    outcome = engine.run(dot_source, logs_root: logs_root, resume: true)

    expect(outcome).to be_success

    final_checkpoint = Attractor::Checkpoint.load(
      Attractor::Checkpoint.checkpoint_path(logs_root)
    )
    expect(final_checkpoint.completed_nodes).to include("step_c", "exit")
  end

  it "checkpoint round-trips correctly" do
    original = Attractor::Checkpoint.new(
      current_node: "step_a",
      completed_nodes: %w[start step_a],
      node_retries: {"step_a" => 2},
      context_values: {"key" => "value", "number" => 42},
      logs: ["entry 1", "entry 2"]
    )

    path = File.join(logs_root, "test_checkpoint.json")
    FileUtils.mkdir_p(logs_root)
    original.save(path)

    loaded = Attractor::Checkpoint.load(path)
    expect(loaded.current_node).to eq("step_a")
    expect(loaded.completed_nodes).to eq(%w[start step_a])
    expect(loaded.node_retries).to eq({"step_a" => 2})
    expect(loaded.context_values).to eq({"key" => "value", "number" => 42})
    expect(loaded.logs).to eq(["entry 1", "entry 2"])
  end
end
