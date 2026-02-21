# frozen_string_literal: true

module Attractor
  module Handlers
    class WaitHumanHandler < BaseHandler
      # Matches: [K] Label, K) Label, K - Label
      ACCELERATOR_PATTERNS = [
        /\A\[(.)\]\s*/,       # [K] Label
        /\A(.)\)\s*/,         # K) Label
        /\A(.)\s*-\s*/        # K - Label
      ].freeze

      def initialize(interviewer:)
        @interviewer = interviewer
      end

      def execute(node, context, graph, logs_root)
        edges = graph.outgoing_edges(node.id)

        if edges.empty?
          return Outcome.new(
            status: StageStatus::FAIL,
            failure_reason: "No outgoing edges for human gate"
          )
        end

        choices = build_choices(edges)
        options = choices.map { |c| Option.new(key: c[:key], label: c[:label]) }

        question_text = node.label.empty? ? "Select an option:" : node.label
        question = Question.new(
          text: question_text,
          type: QuestionType::MULTIPLE_CHOICE,
          options: options,
          timeout_seconds: parse_timeout(node),
          stage: node.id
        )

        answer = @interviewer.ask(question)

        if answer.timeout?
          return handle_timeout(node, choices)
        end

        if answer.skipped?
          return Outcome.new(
            status: StageStatus::FAIL,
            failure_reason: "human skipped interaction"
          )
        end

        selected = find_matching_choice(answer, choices)
        selected = choices.first if selected.nil?

        Outcome.new(
          status: StageStatus::SUCCESS,
          suggested_next_ids: [selected[:to]],
          context_updates: {
            "human.gate.selected" => selected[:key],
            "human.gate.label" => selected[:label]
          }
        )
      end

      private

      def build_choices(edges)
        edges.map do |edge|
          label = edge.label.empty? ? edge.to : edge.label
          key = parse_accelerator_key(label)
          {key: key, label: label, to: edge.to}
        end
      end

      def parse_accelerator_key(label)
        ACCELERATOR_PATTERNS.each do |pattern|
          match = label.match(pattern)
          return match[1].upcase if match
        end

        label[0]&.upcase || ""
      end

      def parse_timeout(node)
        raw = node.timeout
        return nil if raw.nil?
        return nil unless raw.is_a?(Numeric)

        # AttributeTypes coerces duration strings to milliseconds.
        # Convert to seconds for the interviewer.
        raw / 1000.0
      end

      def handle_timeout(node, choices)
        default_choice_key = node.attrs["human.default_choice"]
        if default_choice_key
          selected = choices.find { |c| c[:key].downcase == default_choice_key.to_s.downcase }
          if selected
            return Outcome.new(
              status: StageStatus::SUCCESS,
              suggested_next_ids: [selected[:to]],
              context_updates: {
                "human.gate.selected" => selected[:key],
                "human.gate.label" => selected[:label]
              }
            )
          end
        end

        Outcome.new(
          status: StageStatus::RETRY,
          failure_reason: "human gate timeout, no default"
        )
      end

      def find_matching_choice(answer, choices)
        value = answer.value.to_s.strip

        # Match by key (case-insensitive)
        match = choices.find { |c| c[:key].downcase == value.downcase }
        return match if match

        # Match by selected_option key
        if answer.selected_option
          match = choices.find { |c| c[:key].downcase == answer.selected_option.key.downcase }
          return match if match
        end

        # Match by label substring
        choices.find { |c| c[:label].downcase.include?(value.downcase) }
      end
    end
  end
end
