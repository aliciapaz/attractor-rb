# frozen_string_literal: true

module Attractor
  module Transforms
    class BaseTransform
      def apply(graph)
        raise NotImplementedError, "#{self.class}#apply must be implemented"
      end
    end
  end
end
