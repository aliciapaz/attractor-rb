# frozen_string_literal: true

module Attractor
  class CodergenBackend
    def run(node, prompt, context)
      raise NotImplementedError, "#{self.class}#run must be implemented"
    end
  end
end
