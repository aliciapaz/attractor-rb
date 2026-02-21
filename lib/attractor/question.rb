# frozen_string_literal: true

module Attractor
  module QuestionType
    YES_NO = :yes_no
    MULTIPLE_CHOICE = :multiple_choice
    FREEFORM = :freeform
    CONFIRMATION = :confirmation
  end

  Option = Data.define(:key, :label)

  class Question
    attr_reader :text, :type, :options, :default, :timeout_seconds, :stage, :metadata

    def initialize(text:, type:, options: [], default: nil, timeout_seconds: nil, stage: "", metadata: {})
      @text = text
      @type = type
      @options = options
      @default = default
      @timeout_seconds = timeout_seconds
      @stage = stage
      @metadata = metadata
    end
  end
end
