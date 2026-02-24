# frozen_string_literal: true

module Attractor
  module ProcessHelper
    private

    def capture3_with_timeout(timeout, *cmd)
      stdin, stdout_io, stderr_io, wait_thr = Open3.popen3(*cmd)
      stdin.close

      stdout_reader = Thread.new { stdout_io.read rescue "" }
      stderr_reader = Thread.new { stderr_io.read rescue "" }

      status = Timeout.timeout(timeout) { wait_thr.value }
      [stdout_reader.value, stderr_reader.value, status]
    rescue Timeout::Error
      kill_child(wait_thr&.pid)
      raise
    ensure
      stdout_reader&.join(2)
      stderr_reader&.join(2)
      [stdin, stdout_io, stderr_io].compact.each do |io|
        io.close unless io.closed?
      end
    end

    def kill_child(pid)
      return unless pid

      Process.kill("TERM", pid)
      5.times do
        sleep 0.1
        Process.kill(0, pid)
      end
      Process.kill("KILL", pid)
    rescue Errno::ESRCH, Errno::EPERM
      # already exited or not owned
    end
  end
end
