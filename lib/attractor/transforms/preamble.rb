# frozen_string_literal: true

module Attractor
  module Transforms
    class Preamble < BaseTransform
      def apply(graph)
        graph
      end

      def build_preamble(node, context, graph)
        fidelity = Fidelity.resolve(node: node, graph: graph)

        case fidelity
        when "full"
          nil
        when "truncate"
          build_truncate_preamble(graph)
        when "compact"
          build_compact_preamble(context, graph)
        when "summary:low"
          build_summary_low(context, graph)
        when "summary:medium"
          build_summary_medium(context, graph)
        when "summary:high"
          build_summary_high(context, graph)
        else
          build_compact_preamble(context, graph)
        end
      end

      private

      def build_truncate_preamble(graph)
        lines = []
        lines << "Goal: #{graph.goal}" unless graph.goal.empty?
        lines.join("\n")
      end

      def build_compact_preamble(context, graph)
        lines = []
        lines << "Goal: #{graph.goal}" unless graph.goal.empty?

        last_stage = context.get("last_stage")
        lines << "Last completed stage: #{last_stage}" if last_stage

        outcome = context.get("outcome")
        lines << "Last outcome: #{outcome}" if outcome

        lines.join("\n")
      end

      def build_summary_low(context, graph)
        lines = []
        lines << "Goal: #{graph.goal}" unless graph.goal.empty?

        outcome = context.get("outcome")
        lines << "Current status: #{outcome}" if outcome

        lines.join("\n")
      end

      def build_summary_medium(context, graph)
        lines = []
        lines << "Goal: #{graph.goal}" unless graph.goal.empty?

        last_stage = context.get("last_stage")
        lines << "Last stage: #{last_stage}" if last_stage

        outcome = context.get("outcome")
        lines << "Outcome: #{outcome}" if outcome

        last_response = context.get("last_response")
        lines << "Last response excerpt: #{last_response}" if last_response

        lines.join("\n")
      end

      def build_summary_high(context, graph)
        lines = []
        lines << "Goal: #{graph.goal}" unless graph.goal.empty?

        last_stage = context.get("last_stage")
        lines << "Last stage: #{last_stage}" if last_stage

        outcome = context.get("outcome")
        lines << "Outcome: #{outcome}" if outcome

        last_response = context.get("last_response")
        lines << "Last response: #{last_response}" if last_response

        snapshot = context.snapshot
        context_keys = snapshot.keys.select { |k| k.start_with?("context.") }
        if context_keys.any?
          lines << "Context values:"
          context_keys.each do |key|
            lines << "  #{key}: #{snapshot[key]}"
          end
        end

        lines.join("\n")
      end
    end
  end
end
