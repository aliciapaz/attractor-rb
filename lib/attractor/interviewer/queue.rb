# frozen_string_literal: true

module Attractor
  module Interviewer
    class Queue < Base
      def initialize(answers: [])
        @answers = answers.dup
      end

      def ask(_question)
        if @answers.any?
          @answers.shift
        else
          Answer.new(value: AnswerValue::SKIPPED)
        end
      end
    end
  end
end
