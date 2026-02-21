# frozen_string_literal: true

module Attractor
  module StageStatus
    SUCCESS = "success"
    FAIL = "fail"
    PARTIAL_SUCCESS = "partial_success"
    RETRY = "retry"
    SKIPPED = "skipped"

    ALL = [SUCCESS, FAIL, PARTIAL_SUCCESS, RETRY, SKIPPED].freeze

    def self.success?(status)
      [SUCCESS, PARTIAL_SUCCESS].include?(status)
    end
  end
end
