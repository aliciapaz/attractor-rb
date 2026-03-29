# frozen_string_literal: true

module Attractor
  class CodergenBackend
    include ProcessHelper

    def run(node, prompt, context)
      raise NotImplementedError, "#{self.class}#run must be implemented"
    end
  end
end
