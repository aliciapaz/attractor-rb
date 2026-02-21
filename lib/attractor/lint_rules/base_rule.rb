# frozen_string_literal: true

module Attractor
  module LintRules
    class BaseRule
      def name
        raise NotImplementedError
      end

      def apply(graph)
        raise NotImplementedError
      end
    end
  end
end
