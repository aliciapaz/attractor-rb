# frozen_string_literal: true

RSpec.describe "Linear pipeline integration" do
  let(:logs_root) { Dir.mktmpdir("attractor-test-") }
  let(:backend) { Attractor::Backends::SimulationBackend.new }

  after { FileUtils.rm_rf(logs_root) }

  let(:dot_source) do
    <<~DOT
      digraph Simple {
          graph [goal="Run tests and report"]

          start [shape=Mdiamond, label="Start"]
          exit  [shape=Msquare, label="Exit"]

          run_tests [label="Run Tests", prompt="Run the test suite and report results"]
          report    [label="Report", prompt="Summarize the test results"]

          start -> run_tests -> report -> exit
      }
    DOT
  end

  it "executes start → run_tests → report → exit in order" do
    engine = Attractor::Engine.new(backend: backend)
    outcome = engine.run(dot_source, logs_root: logs_root)

    expect(outcome).to be_success
  end

  it "writes log files for each codergen node" do
    engine = Attractor::Engine.new(backend: backend)
    engine.run(dot_source, logs_root: logs_root)

    %w[run_tests report].each do |node_id|
      expect(File.exist?(File.join(logs_root, node_id, "status.json"))).to be true
    end
  end

  it "writes prompt.md and response.md for codergen nodes" do
    engine = Attractor::Engine.new(backend: backend)
    engine.run(dot_source, logs_root: logs_root)

    %w[run_tests report].each do |node_id|
      node_dir = File.join(logs_root, node_id)
      expect(File.exist?(File.join(node_dir, "prompt.md"))).to be true
      expect(File.exist?(File.join(node_dir, "response.md"))).to be true
    end
  end

  it "saves a checkpoint after execution" do
    engine = Attractor::Engine.new(backend: backend)
    engine.run(dot_source, logs_root: logs_root)

    checkpoint_path = File.join(logs_root, "checkpoint.json")
    expect(File.exist?(checkpoint_path)).to be true

    checkpoint = Attractor::Checkpoint.load(checkpoint_path)
    expect(checkpoint.completed_nodes).to include("start", "run_tests", "report", "exit")
  end

  it "propagates context between nodes" do
    events = []
    engine = Attractor::Engine.new(backend: backend)
    engine.event_emitter.on_event { |e| events << e }

    engine.run(dot_source, logs_root: logs_root)

    stage_completed = events.select { |e| e.is_a?(Attractor::Events::StageCompleted) }
    expect(stage_completed.map(&:name)).to include("run_tests", "report")
  end

  it "writes a manifest file" do
    engine = Attractor::Engine.new(backend: backend)
    engine.run(dot_source, logs_root: logs_root)

    manifest_path = File.join(logs_root, "manifest.json")
    expect(File.exist?(manifest_path)).to be true

    manifest = JSON.parse(File.read(manifest_path))
    expect(manifest["goal"]).to eq("Run tests and report")
  end
end
