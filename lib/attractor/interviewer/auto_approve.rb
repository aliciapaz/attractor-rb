# frozen_string_literal: true

module Attractor
  module Interviewer
    class AutoApprove < Base
      def ask(question)
        case question.type
        when QuestionType::YES_NO, QuestionType::CONFIRMATION
          Answer.new(value: AnswerValue::YES)
        when QuestionType::MULTIPLE_CHOICE
          if question.options.any?
            first = question.options.first
            Answer.new(value: first.key, selected_option: first)
          else
            Answer.new(value: "auto-approved", text: "auto-approved")
          end
        else
          Answer.new(value: "auto-approved", text: "auto-approved")
        end
      end
    end
  end
end
