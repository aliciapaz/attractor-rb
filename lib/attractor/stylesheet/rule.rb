# frozen_string_literal: true

module Attractor
  module Stylesheet
    class Rule
      attr_reader :selector, :declarations

      def initialize(selector:, declarations:)
        @selector = selector
        @declarations = declarations
      end

      def specificity
        case selector
        when /\A#/ then 2
        when /\A\./ then 1
        else 0
        end
      end

      def matches?(node)
        case selector
        when "*"
          true
        when /\A#(.+)\z/
          node.id == ::Regexp.last_match(1)
        when /\A\.(.+)\z/
          node.classes.include?(::Regexp.last_match(1))
        else
          false
        end
      end
    end
  end
end
