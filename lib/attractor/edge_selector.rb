# frozen_string_literal: true

module Attractor
  class EdgeSelector
    def select(node, outcome, context, graph)
      edges = graph.outgoing_edges(node.id)
      return nil if edges.empty?

      # Step 1: Condition matching
      matched = condition_matched(edges, outcome, context)
      return best_by_weight_then_lexical(matched) if matched.any?

      # Step 2: Preferred label
      if outcome.preferred_label && !outcome.preferred_label.empty?
        edge = find_by_label(edges, outcome.preferred_label)
        return edge if edge
      end

      # Step 3: Suggested next IDs
      if outcome.suggested_next_ids&.any?
        edge = find_by_suggested(edges, outcome.suggested_next_ids)
        return edge if edge
      end

      # Step 4 & 5: Weight with lexical tiebreak (unconditional only)
      unconditional = edges.select { |e| e.condition.empty? }
      return best_by_weight_then_lexical(unconditional) if unconditional.any?

      # No valid edge: all edges are conditional and none matched
      nil
    end

    private

    def condition_matched(edges, outcome, context)
      edges.select { |e| !e.condition.empty? && Condition::Evaluator.evaluate(e.condition, outcome, context) }
    end

    def find_by_label(edges, preferred)
      normalized = normalize_label(preferred)
      edges.find { |e| normalize_label(e.label) == normalized }
    end

    def find_by_suggested(edges, suggested_ids)
      suggested_ids.each do |sid|
        edge = edges.find { |e| e.to == sid }
        return edge if edge
      end
      nil
    end

    def best_by_weight_then_lexical(edges)
      edges.min_by { |e| [-e.weight, e.to] }
    end

    def normalize_label(label)
      return "" if label.nil? || label.empty?

      text = label.strip.downcase
      # Strip accelerator prefixes: [K] , K) , K -
      text = text.sub(/\A\[.\]\s*/, "")
      text = text.sub(/\A.\)\s*/, "")
      text = text.sub(/\A.\s*-\s*/, "")
      text.strip
    end
  end
end
