# frozen_string_literal: true

module Attractor
  module Stylesheet
    module Parser
      VALID_PROPERTIES = %w[llm_model llm_provider reasoning_effort].freeze
      SELECTOR_PATTERN = /\A(\*|#[A-Za-z_][A-Za-z0-9_]*|\.[a-z0-9-]+)\z/

      def self.parse(source)
        return [] if source.nil? || source.strip.empty?

        rules = []
        remaining = source.strip

        until remaining.empty?
          remaining = remaining.lstrip
          break if remaining.empty?

          selector, remaining = extract_selector(remaining)
          remaining = expect_char(remaining, "{")
          declarations, remaining = extract_declarations(remaining)
          remaining = expect_char(remaining, "}")

          rules << Rule.new(selector: selector, declarations: declarations)
        end

        rules
      end

      def self.valid?(source)
        return true if source.nil? || source.strip.empty?

        parse(source)
        true
      rescue ParseError
        false
      end

      def self.extract_selector(source)
        source = source.lstrip
        match = source.match(/\A(\S+)\s*/)
        raise ParseError, "Expected selector" unless match

        selector = match[1]
        unless selector.match?(SELECTOR_PATTERN)
          raise ParseError, "Invalid selector '#{selector}'"
        end

        [selector, source[match[0].length..]]
      end

      def self.expect_char(source, char)
        source = source.lstrip
        unless source.start_with?(char)
          raise ParseError, "Expected '#{char}' but got '#{source[0]}'"
        end
        source[1..]
      end

      def self.extract_declarations(source)
        declarations = {}
        remaining = source.lstrip

        until remaining.start_with?("}")
          remaining = remaining.lstrip
          break if remaining.start_with?("}")

          property, value, remaining = extract_declaration(remaining)
          declarations[property] = value
        end

        [declarations, remaining]
      end

      def self.extract_declaration(source)
        source = source.lstrip

        colon_idx = source.index(":")
        raise ParseError, "Expected ':' in declaration" unless colon_idx

        property = source[0...colon_idx].strip
        rest = source[(colon_idx + 1)..]

        semi_idx = rest.index(";")
        brace_idx = rest.index("}")

        if semi_idx
          value = rest[0...semi_idx].strip
          remaining = rest[(semi_idx + 1)..]
        elsif brace_idx
          value = rest[0...brace_idx].strip
          remaining = rest[brace_idx..]
        else
          raise ParseError, "Expected ';' or '}' after declaration value"
        end

        raise ParseError, "Empty property name" if property.empty?
        raise ParseError, "Empty value for property '#{property}'" if value.empty?

        [property, value, remaining]
      end

      private_class_method :extract_selector, :expect_char,
        :extract_declarations, :extract_declaration

      class ParseError < Attractor::Error; end
    end
  end
end
