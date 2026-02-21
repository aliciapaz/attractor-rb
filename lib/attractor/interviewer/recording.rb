# frozen_string_literal: true

module Attractor
  module Interviewer
    class Recording < Base
      attr_reader :recordings

      def initialize(inner)
        @inner = inner
        @recordings = []
      end

      def ask(question)
        answer = @inner.ask(question)
        @recordings << [question, answer]
        answer
      end

      def inform(message, stage: "")
        @inner.inform(message, stage: stage)
      end
    end
  end
end
