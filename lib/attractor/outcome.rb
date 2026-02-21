# frozen_string_literal: true

module Attractor
  class Outcome
    attr_reader :status, :preferred_label, :suggested_next_ids,
      :context_updates, :notes, :failure_reason

    def initialize(
      status:,
      preferred_label: "",
      suggested_next_ids: [],
      context_updates: {},
      notes: "",
      failure_reason: ""
    )
      @status = status
      @preferred_label = preferred_label
      @suggested_next_ids = suggested_next_ids
      @context_updates = context_updates
      @notes = notes
      @failure_reason = failure_reason
    end

    def success?
      StageStatus.success?(status)
    end

    def to_h
      {
        outcome: status,
        preferred_next_label: preferred_label,
        suggested_next_ids: suggested_next_ids,
        context_updates: context_updates,
        notes: notes
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
