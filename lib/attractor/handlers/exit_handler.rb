# frozen_string_literal: true

module Attractor
  module Handlers
    class ExitHandler < BaseHandler
      def execute(_node, _context, _graph, _logs_root)
        Outcome.new(status: StageStatus::SUCCESS)
      end
    end
  end
end
