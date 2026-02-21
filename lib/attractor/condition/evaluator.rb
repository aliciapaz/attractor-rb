# frozen_string_literal: true

module Attractor
  module Condition
    module Evaluator
      def self.evaluate(condition_string, outcome, context)
        return true if condition_string.nil? || condition_string.strip.empty?

        clauses = condition_string.split("&&")
        clauses.each do |clause_str|
          clause_str = clause_str.strip
          next if clause_str.empty?

          return false unless evaluate_clause(clause_str, outcome, context)
        end

        true
      end

      def self.evaluate_clause(clause_str, outcome, context)
        if clause_str.include?("!=")
          key, value = clause_str.split("!=", 2)
          resolve_key(key.strip, outcome, context) != value.strip
        elsif clause_str.include?("=")
          key, value = clause_str.split("=", 2)
          resolve_key(key.strip, outcome, context) == value.strip
        else
          resolved = resolve_key(clause_str.strip, outcome, context)
          !resolved.empty?
        end
      end

      def self.resolve_key(key, outcome, context)
        if key == "outcome"
          return outcome&.status.to_s
        end

        if key == "preferred_label"
          return (outcome&.preferred_label || "").to_s
        end

        if key.start_with?("context.")
          value = context_get(context, key)
          return value.to_s unless value.nil?

          bare_key = key.sub(/\Acontext\./, "")
          value = context_get(context, bare_key)
          return value.to_s unless value.nil?

          return ""
        end

        value = context_get(context, key)
        return value.to_s unless value.nil?

        ""
      end

      def self.context_get(context, key)
        if context.respond_to?(:get)
          context.get(key)
        elsif context.respond_to?(:[])
          context[key]
        end
      end

      private_class_method :evaluate_clause, :resolve_key, :context_get
    end
  end
end
