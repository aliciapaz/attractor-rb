# frozen_string_literal: true

module Attractor
  module Interviewer
    class Base
      def ask(question)
        raise NotImplementedError, "#{self.class}#ask must be implemented"
      end

      def ask_multiple(questions)
        questions.map { |q| ask(q) }
      end

      def inform(message, stage: "")
        # Default: no-op
      end
    end
  end
end
