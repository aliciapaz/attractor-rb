# frozen_string_literal: true

module Attractor
  module Handlers
    class ConditionalHandler < BaseHandler
      def execute(node, _context, _graph, _logs_root)
        Outcome.new(
          status: StageStatus::SUCCESS,
          notes: "Conditional node evaluated: #{node.id}"
        )
      end
    end
  end
end
