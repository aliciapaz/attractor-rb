# frozen_string_literal: true

RSpec.describe Attractor::Cli::ValidateCommand do
  let(:tmpdir) { Dir.mktmpdir("attractor-cli-test") }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#execute" do
    context "with a valid DOT file" do
      it "prints validation passed" do
        dotfile = File.join(tmpdir, "valid.dot")
        File.write(dotfile, <<~DOT)
          digraph Valid {
            graph [goal="Test"]
            start [shape=Mdiamond]
            step [shape=box, prompt="Work"]
            exit [shape=Msquare]
            start -> step -> exit
          }
        DOT

        command = described_class.new(dotfile)

        expect { command.execute }.to output(/Validation passed/).to_stdout
      end
    end

    context "with an invalid DOT file (no start node)" do
      it "prints errors to stderr and exits" do
        dotfile = File.join(tmpdir, "invalid.dot")
        File.write(dotfile, <<~DOT)
          digraph Invalid {
            step [shape=box, prompt="Work"]
            exit [shape=Msquare]
            step -> exit
          }
        DOT

        command = described_class.new(dotfile)

        expect { command.execute }.to raise_error(SystemExit).and output(/Validation failed|ERROR/).to_stderr
      end
    end

    context "with a missing DOT file" do
      it "prints error and exits" do
        command = described_class.new("/nonexistent/file.dot")

        expect { command.execute }.to raise_error(SystemExit).and output(/DOT file not found/).to_stderr
      end
    end

    context "with a malformed DOT file" do
      it "prints parse error and exits" do
        dotfile = File.join(tmpdir, "bad.dot")
        File.write(dotfile, "not valid dot syntax at all {{{")

        command = described_class.new(dotfile)

        expect { command.execute }.to raise_error(SystemExit).and output(/Parse error|Error/).to_stderr
      end
    end
  end
end
