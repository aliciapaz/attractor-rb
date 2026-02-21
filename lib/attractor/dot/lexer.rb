# frozen_string_literal: true

module Attractor
  module Dot
    Token = Data.define(:type, :value, :line, :column)

    class Lexer
      KEYWORDS = {
        "digraph" => :DIGRAPH,
        "graph" => :GRAPH,
        "node" => :NODE,
        "edge" => :EDGE,
        "subgraph" => :SUBGRAPH,
        "true" => :BOOLEAN,
        "false" => :BOOLEAN
      }.freeze

      SINGLE_CHARS = {
        "{" => :LBRACE,
        "}" => :RBRACE,
        "[" => :LBRACKET,
        "]" => :RBRACKET,
        "," => :COMMA,
        "=" => :EQUALS,
        ";" => :SEMICOLON
      }.freeze

      def initialize(source)
        @source = source
        @tokens = []
        @pos = 0
        @line = 1
        @column = 1
        @lines = source.lines.map(&:chomp)
      end

      def tokenize
        stripped = strip_comments(@source)
        @pos = 0
        @line = 1
        @column = 1
        @chars = stripped
        @lines = stripped.lines.map(&:chomp)

        scan_tokens
        @tokens << Token.new(type: :EOF, value: nil, line: @line, column: @column)
        @tokens
      end

      private

      def strip_comments(src)
        result = +""
        i = 0
        while i < src.length
          if i + 1 < src.length && src[i] == "/" && src[i + 1] == "/"
            # Line comment: skip until newline
            while i < src.length && src[i] != "\n"
              i += 1
            end
          elsif i + 1 < src.length && src[i] == "/" && src[i + 1] == "*"
            # Block comment: skip until */
            i += 2
            while i + 1 < src.length && !(src[i] == "*" && src[i + 1] == "/")
              result << "\n" if src[i] == "\n"
              i += 1
            end
            if i + 1 >= src.length
              raise ParseError.new("Unterminated block comment", line: 1, column: 1, source_line: nil)
            end
            i += 2 # skip */
          elsif src[i] == '"'
            # Inside a string literal: don't strip comments
            result << src[i]
            i += 1
            while i < src.length && src[i] != '"'
              if src[i] == "\\" && i + 1 < src.length
                result << src[i] << src[i + 1]
                i += 2
              else
                result << src[i]
                i += 1
              end
            end
            result << src[i] if i < src.length # closing quote
            i += 1
          else
            result << src[i]
            i += 1
          end
        end
        result
      end

      def scan_tokens
        while @pos < @chars.length
          ch = @chars[@pos]

          case ch
          when "\n"
            advance
            @line += 1
            @column = 1
          when " ", "\t", "\r"
            advance
          when "{", "}", "[", "]", ",", "=", ";"
            @tokens << Token.new(
              type: SINGLE_CHARS[ch],
              value: ch,
              line: @line,
              column: @column
            )
            advance
          when "-"
            scan_dash
          when "."
            if @pos + 1 < @chars.length && @chars[@pos + 1] =~ /[0-9]/
              scan_number
            else
              @tokens << Token.new(type: :DOT, value: ".", line: @line, column: @column)
              advance
            end
          when '"'
            scan_string
          when /[0-9]/
            scan_number
          when /[A-Za-z_]/
            scan_identifier
          else
            raise_error("Unexpected character: #{ch.inspect}")
          end
        end
      end

      def scan_dash
        start_col = @column
        if @pos + 1 < @chars.length && @chars[@pos + 1] == ">"
          @tokens << Token.new(type: :ARROW, value: "->", line: @line, column: start_col)
          advance
          advance
        elsif @pos + 1 < @chars.length && @chars[@pos + 1] == "-"
          raise_error("Undirected edges (--) are not supported; use directed edges (->) instead")
        elsif @pos + 1 < @chars.length && @chars[@pos + 1] =~ /[0-9.]/
          scan_number
        else
          raise_error("Unexpected character: '-'")
        end
      end

      def scan_string
        start_line = @line
        start_col = @column
        advance # skip opening quote

        value = +""
        while @pos < @chars.length && @chars[@pos] != '"'
          if @chars[@pos] == "\\"
            advance
            if @pos >= @chars.length
              raise ParseError.new(
                "Unterminated string escape",
                line: start_line,
                column: start_col,
                source_line: source_line_at(start_line)
              )
            end
            value << case @chars[@pos]
            when '"' then '"'
            when "n" then "\n"
            when "t" then "\t"
            when "\\" then "\\"
            else @chars[@pos]
            end
            advance
          elsif @chars[@pos] == "\n"
            value << "\n"
            advance
            @line += 1
            @column = 1
          else
            value << @chars[@pos]
            advance
          end
        end

        if @pos >= @chars.length
          raise ParseError.new(
            "Unterminated string literal",
            line: start_line,
            column: start_col,
            source_line: source_line_at(start_line)
          )
        end

        advance # skip closing quote
        @tokens << Token.new(type: :STRING, value: value, line: start_line, column: start_col)
      end

      def scan_number
        start_col = @column
        start_pos = @pos
        is_float = false

        advance if @chars[@pos] == "-"

        while @pos < @chars.length && @chars[@pos] =~ /[0-9]/
          advance
        end

        if @pos < @chars.length && @chars[@pos] == "." && @pos + 1 < @chars.length && @chars[@pos + 1] =~ /[0-9]/
          is_float = true
          advance # skip dot
          while @pos < @chars.length && @chars[@pos] =~ /[0-9]/
            advance
          end
        end

        raw = @chars[start_pos...@pos]

        @tokens << if is_float
          Token.new(type: :FLOAT, value: raw.to_f, line: @line, column: start_col)
        else
          Token.new(type: :INTEGER, value: raw.to_i, line: @line, column: start_col)
        end
      end

      def scan_identifier
        start_col = @column
        start_pos = @pos

        while @pos < @chars.length && @chars[@pos] =~ /[A-Za-z0-9_]/
          advance
        end

        word = @chars[start_pos...@pos]

        @tokens << if KEYWORDS.key?(word)
          Token.new(type: KEYWORDS[word], value: word, line: @line, column: start_col)
        else
          Token.new(type: :IDENTIFIER, value: word, line: @line, column: start_col)
        end
      end

      def advance
        @column += 1
        @pos += 1
      end

      def source_line_at(line_num)
        @lines[line_num - 1]
      end

      def raise_error(message)
        raise ParseError.new(
          message,
          line: @line,
          column: @column,
          source_line: source_line_at(@line)
        )
      end
    end
  end
end
