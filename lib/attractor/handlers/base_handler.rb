# frozen_string_literal: true

module Attractor
  module Handlers
    class BaseHandler
      def execute(node, context, graph, logs_root)
        raise NotImplementedError, "#{self.class}#execute must be implemented"
      end
    end
  end
end
