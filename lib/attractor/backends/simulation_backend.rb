# frozen_string_literal: true

module Attractor
  module Backends
    class SimulationBackend < CodergenBackend
      def run(node, _prompt, _context)
        "[Simulated] Response for: #{node.id}"
      end
    end
  end
end
