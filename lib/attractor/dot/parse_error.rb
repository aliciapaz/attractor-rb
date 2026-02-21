# frozen_string_literal: true

module Attractor
  module Dot
    class ParseError < Attractor::Error
      attr_reader :line, :column, :source_line

      def initialize(message, line: nil, column: nil, source_line: nil)
        @line = line
        @column = column
        @source_line = source_line
        full_msg = message
        full_msg = "Line #{line}, Col #{column}: #{message}" if line && column
        full_msg += "\n  #{source_line}" if source_line
        super(full_msg)
      end
    end
  end
end
