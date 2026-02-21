# frozen_string_literal: true

module Attractor
  module Interviewer
    class Callback < Base
      def initialize(handler)
        @handler = handler
      end

      def ask(question)
        @handler.call(question)
      end
    end
  end
end
