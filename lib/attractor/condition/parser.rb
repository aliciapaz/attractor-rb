# frozen_string_literal: true

module Attractor
  module Condition
    Clause = Struct.new(:key, :operator, :value, keyword_init: true)

    module Parser
      VALID_OPERATORS = %w[= !=].freeze

      def self.parse(expr)
        return [] if expr.nil? || expr.strip.empty?

        clauses = expr.split("&&").map(&:strip)
        raise ParseError, "Empty clause in condition" if clauses.empty? || clauses.any?(&:empty?)

        clauses.map { |clause_str| parse_clause(clause_str) }
      end

      def self.valid?(expr)
        return true if expr.nil? || expr.strip.empty?

        parse(expr)
        true
      rescue ParseError
        false
      end

      def self.parse_clause(clause_str)
        raise ParseError, "Empty clause in condition" if clause_str.empty?

        if clause_str.include?("!=")
          key, value = clause_str.split("!=", 2)
          validate_parts!(key, "!=", value, clause_str)
          Clause.new(key: key.strip, operator: "!=", value: value.strip)
        elsif clause_str.include?("=")
          key, value = clause_str.split("=", 2)
          validate_parts!(key, "=", value, clause_str)
          Clause.new(key: key.strip, operator: "=", value: value.strip)
        else
          validate_bare_key!(clause_str)
          Clause.new(key: clause_str.strip, operator: nil, value: nil)
        end
      end

      def self.validate_parts!(key, operator, value, original)
        key = key&.strip
        value = value&.strip
        if key.nil? || key.empty?
          raise ParseError, "Missing key in clause '#{original}'"
        end
        if value.nil?
          raise ParseError, "Missing value in clause '#{original}'"
        end
      end

      def self.validate_bare_key!(key)
        stripped = key.strip
        if stripped.empty?
          raise ParseError, "Empty bare key in condition"
        end
      end

      private_class_method :parse_clause, :validate_parts!, :validate_bare_key!

      class ParseError < Attractor::Error; end
    end
  end
end
