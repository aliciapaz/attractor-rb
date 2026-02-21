# frozen_string_literal: true

module Attractor
  class Validator
    BUILT_IN_RULES = [
      LintRules::StartNodeRule.new,
      LintRules::TerminalNodeRule.new,
      LintRules::ReachabilityRule.new,
      LintRules::EdgeTargetExistsRule.new,
      LintRules::StartNoIncomingRule.new,
      LintRules::ExitNoOutgoingRule.new,
      LintRules::ConditionSyntaxRule.new,
      LintRules::StylesheetSyntaxRule.new,
      LintRules::TypeKnownRule.new,
      LintRules::FidelityValidRule.new,
      LintRules::RetryTargetExistsRule.new,
      LintRules::GoalGateHasRetryRule.new,
      LintRules::PromptOnLlmNodesRule.new
    ].freeze

    def validate(graph, extra_rules: [])
      rules = BUILT_IN_RULES + extra_rules
      rules.flat_map { |rule| rule.apply(graph) }
    end

    def validate_or_raise(graph, extra_rules: [])
      diagnostics = validate(graph, extra_rules: extra_rules)
      errors = diagnostics.select(&:error?)
      if errors.any?
        messages = errors.map(&:message).join("; ")
        raise ValidationError, "Validation failed: #{messages}"
      end
      diagnostics
    end
  end
end
