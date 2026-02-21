# frozen_string_literal: true

RSpec.describe Attractor::Cli::RunCommand do
  let(:logs_root) { Dir.mktmpdir("attractor-cli-test") }
  let(:dotfile_path) { File.join(logs_root, "test.dot") }

  after { FileUtils.rm_rf(logs_root) }

  let(:dot_source) do
    <<~DOT
      digraph Test {
        graph [goal="CLI test"]
        start [shape=Mdiamond]
        step [shape=box, prompt="Do work"]
        exit [shape=Msquare]
        start -> step -> exit
      }
    DOT
  end

  before do
    File.write(dotfile_path, dot_source)
  end

  describe "#execute" do
    context "with a successful pipeline" do
      it "prints success to stdout" do
        options = {logs_root: logs_root, backend: "simulation", interviewer: "auto_approve", resume: false}
        command = described_class.new(dotfile_path, options)

        expect { command.execute }.to output(/Pipeline completed successfully/).to_stdout
      end
    end

    context "with a missing dotfile" do
      it "prints error to stderr and exits" do
        options = {logs_root: logs_root, backend: "simulation", interviewer: "auto_approve", resume: false}
        command = described_class.new("/nonexistent/file.dot", options)

        expect { command.execute }.to raise_error(SystemExit).and output(/DOT file not found/).to_stderr
      end
    end

    context "backend selection" do
      it "defaults to simulation backend for unknown values" do
        options = {logs_root: logs_root, backend: "unknown", interviewer: "auto_approve", resume: false}
        command = described_class.new(dotfile_path, options)

        expect { command.execute }.to output(/Pipeline completed successfully/).to_stdout
      end
    end
  end
end
