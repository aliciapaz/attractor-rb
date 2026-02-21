# frozen_string_literal: true

module Attractor
  module Interviewer
    class Console < Base
      def initialize(input: $stdin, output: $stdout)
        @input = input
        @output = output
      end

      def ask(question)
        @output.puts "[?] #{question.text}"

        case question.type
        when QuestionType::MULTIPLE_CHOICE
          ask_multiple_choice(question)
        when QuestionType::YES_NO, QuestionType::CONFIRMATION
          ask_yes_no(question)
        when QuestionType::FREEFORM
          ask_freeform(question)
        else
          ask_freeform(question)
        end
      end

      def inform(message, stage: "")
        prefix = stage.empty? ? "[i]" : "[i:#{stage}]"
        @output.puts "#{prefix} #{message}"
      end

      private

      def ask_multiple_choice(question)
        question.options.each do |option|
          @output.puts "  [#{option.key}] #{option.label}"
        end

        response = read_with_timeout("Select: ", question.timeout_seconds)
        return handle_timeout(question) if response.nil?

        response = response.strip
        matched = question.options.find { |o| o.key.downcase == response.downcase }
        if matched
          Answer.new(value: matched.key, selected_option: matched)
        elsif question.options.any?
          first = question.options.first
          Answer.new(value: first.key, selected_option: first)
        else
          Answer.new(value: response, text: response)
        end
      end

      def ask_yes_no(question)
        response = read_with_timeout("[Y/N]: ", question.timeout_seconds)
        return handle_timeout(question) if response.nil?

        response = response.strip.downcase
        if %w[y yes].include?(response)
          Answer.new(value: AnswerValue::YES)
        else
          Answer.new(value: AnswerValue::NO)
        end
      end

      def ask_freeform(question)
        response = read_with_timeout("> ", question.timeout_seconds)
        return handle_timeout(question) if response.nil?

        Answer.new(text: response.strip)
      end

      def read_with_timeout(prompt_text, timeout_seconds)
        @output.print prompt_text
        @output.flush

        if timeout_seconds && timeout_seconds > 0
          result = nil
          thread = Thread.new { result = @input.gets }
          unless thread.join(timeout_seconds)
            thread.kill
            return nil
          end
          result
        else
          @input.gets
        end
      end

      def handle_timeout(question)
        @output.puts "\n[timeout]"
        return question.default if question.default

        Answer.new(value: AnswerValue::TIMEOUT)
      end
    end
  end
end
