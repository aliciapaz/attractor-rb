# frozen_string_literal: true

RSpec.describe Attractor::ProcessHelper do
  subject(:helper) { Class.new { include Attractor::ProcessHelper }.new }

  describe "#capture3_with_timeout" do
    it "returns stdout, stderr, and status" do
      stdout, stderr, status = helper.send(:capture3_with_timeout, 5, "echo", "hello")

      expect(stdout.strip).to eq("hello")
      expect(stderr).to eq("")
      expect(status.success?).to be true
    end

    it "captures stderr" do
      _, stderr, status = helper.send(:capture3_with_timeout, 5, "sh", "-c", "echo oops >&2; exit 1")

      expect(stderr.strip).to eq("oops")
      expect(status.success?).to be false
    end

    it "raises Errno::ENOENT for missing command" do
      expect {
        helper.send(:capture3_with_timeout, 5, "nonexistent_command_xyz_#{rand(99999)}")
      }.to raise_error(Errno::ENOENT)
    end

    it "kills the child process on timeout" do
      pidfile = Tempfile.new("attractor-test-pid")
      pidfile.close

      expect {
        helper.send(:capture3_with_timeout, 0.5,
          "sh", "-c", "echo $$ > #{pidfile.path} && sleep 60")
      }.to raise_error(Timeout::Error)

      sleep 0.3 # allow kill_child cleanup to complete

      child_pid = File.read(pidfile.path).strip.to_i
      expect(child_pid).to be > 0
      expect { Process.kill(0, child_pid) }.to raise_error(Errno::ESRCH)
    ensure
      pidfile&.unlink
    end
  end

  describe "#kill_child" do
    it "terminates a running process" do
      pid = Process.spawn("sleep", "60")

      helper.send(:kill_child, pid)

      _, status = Process.waitpid2(pid)
      expect(status.signaled?).to be true
    end

    it "handles already-exited processes" do
      pid = Process.spawn("true")
      Process.waitpid(pid)

      expect { helper.send(:kill_child, pid) }.not_to raise_error
    end

    it "handles nil pid" do
      expect { helper.send(:kill_child, nil) }.not_to raise_error
    end
  end
end
