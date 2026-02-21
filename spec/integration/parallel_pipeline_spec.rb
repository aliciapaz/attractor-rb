# frozen_string_literal: true

RSpec.describe "Parallel pipeline integration" do
  let(:logs_root) { Dir.mktmpdir("attractor-test-") }

  after { FileUtils.rm_rf(logs_root) }

  let(:dot_source) do
    <<~DOT
      digraph Parallel {
          graph [goal="Implement in parallel"]

          start    [shape=Mdiamond, label="Start"]
          exit     [shape=Msquare, label="Exit"]

          fan_out  [shape=component, label="Fan Out"]
          branch_a [shape=box, prompt="Implement approach A"]
          branch_b [shape=box, prompt="Implement approach B"]
          branch_c [shape=box, prompt="Implement approach C"]
          fan_in   [shape=tripleoctagon, label="Select Best"]

          start -> fan_out
          fan_out -> branch_a
          fan_out -> branch_b
          fan_out -> branch_c
          branch_a -> fan_in
          branch_b -> fan_in
          branch_c -> fan_in
          fan_in -> exit
      }
    DOT
  end

  it "executes parallel fan-out and fan-in" do
    backend = Attractor::Backends::SimulationBackend.new
    engine = Attractor::Engine.new(backend: backend)
    outcome = engine.run(dot_source, logs_root: logs_root)

    expect(outcome).to be_success
  end

  it "writes status files for the parallel handler" do
    backend = Attractor::Backends::SimulationBackend.new
    engine = Attractor::Engine.new(backend: backend)
    engine.run(dot_source, logs_root: logs_root)

    expect(File.exist?(File.join(logs_root, "fan_out", "status.json"))).to be true
  end
end
