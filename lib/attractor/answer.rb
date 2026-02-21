# frozen_string_literal: true

module Attractor
  module AnswerValue
    YES = "yes"
    NO = "no"
    SKIPPED = "skipped"
    TIMEOUT = "timeout"
  end

  class Answer
    attr_reader :value, :selected_option, :text

    def initialize(value: nil, selected_option: nil, text: "")
      @value = value
      @selected_option = selected_option
      @text = text
    end

    def timeout? = value == AnswerValue::TIMEOUT
    def skipped? = value == AnswerValue::SKIPPED
  end
end
