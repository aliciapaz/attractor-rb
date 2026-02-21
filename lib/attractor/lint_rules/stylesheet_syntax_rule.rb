# frozen_string_literal: true

module Attractor
  module LintRules
    class StylesheetSyntaxRule < BaseRule
      def name
        "stylesheet_syntax"
      end

      def apply(graph)
        stylesheet = graph.model_stylesheet
        return [] if stylesheet.is_a?(String) && stylesheet.strip.empty?

        return [] if Stylesheet::Parser.valid?(stylesheet.to_s)

        [
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_ERROR,
            message: "Graph model_stylesheet has invalid syntax",
            fix: "Fix the stylesheet to use valid CSS-like syntax: selector { property: value; }"
          )
        ]
      end
    end
  end
end
