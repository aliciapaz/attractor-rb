# frozen_string_literal: true

module Attractor
  module Dot
    class Parser
      def self.parse(source)
        new(source).parse
      end

      def initialize(source)
        @tokens = Lexer.new(source).tokenize
        @pos = 0
        @source_lines = source.lines.map(&:chomp)
        @node_defaults = {}
        @edge_defaults = {}
        @nodes = {}
        @edges = []
        @graph_attrs = {}
      end

      def parse
        expect(:DIGRAPH)
        name = expect_identifier
        expect(:LBRACE)
        parse_statements
        expect(:RBRACE)
        expect(:EOF)

        Graph.new(name, nodes: @nodes, edges: @edges, attrs: @graph_attrs)
      end

      private

      def parse_statements
        loop do
          break if peek_type == :RBRACE || peek_type == :EOF

          parse_statement
        end
      end

      def parse_statement
        case peek_type
        when :GRAPH
          parse_graph_attr_stmt
        when :NODE
          parse_node_defaults
        when :EDGE
          parse_edge_defaults
        when :SUBGRAPH
          parse_subgraph_stmt
        when :IDENTIFIER
          parse_identifier_stmt
        else
          raise_parse_error("Unexpected token #{peek_type} (#{peek_value.inspect}), expected a statement")
        end
      end

      def parse_graph_attr_stmt
        consume # consume 'graph'
        attrs = parse_attr_block
        consume_optional(:SEMICOLON)
        @graph_attrs.merge!(attrs)
      end

      def parse_node_defaults
        consume # consume 'node'
        attrs = parse_attr_block
        consume_optional(:SEMICOLON)
        @node_defaults.merge!(attrs)
      end

      def parse_edge_defaults
        consume # consume 'edge'
        attrs = parse_attr_block
        consume_optional(:SEMICOLON)
        @edge_defaults.merge!(attrs)
      end

      def parse_subgraph_stmt
        consume # consume 'subgraph'

        saved_node_defaults = @node_defaults.dup
        saved_edge_defaults = @edge_defaults.dup

        subgraph_name = nil
        subgraph_name = expect_identifier if peek_type == :IDENTIFIER

        expect(:LBRACE)

        # Peek for subgraph-level attrs before parsing statements
        parse_subgraph_body(subgraph_name)

        expect(:RBRACE)
        consume_optional(:SEMICOLON)

        @node_defaults = saved_node_defaults
        @edge_defaults = saved_edge_defaults
      end

      def parse_subgraph_body(_subgraph_name)
        subgraph_label = nil
        subgraph_attrs = {}

        loop do
          break if peek_type == :RBRACE || peek_type == :EOF

          case peek_type
          when :GRAPH
            consume
            attrs = parse_attr_block
            consume_optional(:SEMICOLON)
            # Subgraph graph attrs are scoped to the subgraph, not propagated
            subgraph_attrs.merge!(attrs)
          when :NODE
            parse_node_defaults
          when :EDGE
            parse_edge_defaults
          when :SUBGRAPH
            parse_subgraph_stmt
          when :IDENTIFIER
            # Check for subgraph-level key=value (e.g., label = "Loop A")
            if peek_type_at(1) == :EQUALS && !looks_like_edge?
              key, value = parse_graph_attr_decl_tokens
              if key == "label"
                subgraph_label = value
                apply_subgraph_class(value)
              end
              subgraph_attrs[key] = value
            else
              parse_identifier_stmt_with_subgraph_class(subgraph_label)
            end
          else
            raise_parse_error("Unexpected token #{peek_type} in subgraph")
          end
        end
      end

      def apply_subgraph_class(label)
        derived = derive_class_from_label(label)
        @node_defaults = @node_defaults.merge("class" => derived) if derived && !derived.empty?
      end

      def derive_class_from_label(label)
        label
          .downcase
          .gsub(/\s+/, "-")
          .gsub(/[^a-z0-9-]/, "")
      end

      def parse_identifier_stmt_with_subgraph_class(subgraph_label)
        parse_identifier_stmt
      end

      def parse_identifier_stmt
        id = expect_identifier

        case peek_type
        when :ARROW
          parse_edge_stmt(id)
        when :EQUALS
          # GraphAttrDecl: key = value
          consume # consume '='
          value = parse_value
          consume_optional(:SEMICOLON)
          @graph_attrs[id] = value
        when :LBRACKET
          # NodeStmt with attrs
          attrs = parse_attr_block
          consume_optional(:SEMICOLON)
          register_node(id, attrs)
        else
          # Bare NodeStmt
          consume_optional(:SEMICOLON)
          register_node(id, {})
        end
      end

      def parse_edge_stmt(from_id)
        node_ids = [from_id]

        while peek_type == :ARROW
          consume # consume '->'
          node_ids << expect_identifier
        end

        attrs = {}
        attrs = parse_attr_block if peek_type == :LBRACKET
        consume_optional(:SEMICOLON)

        merged_attrs = @edge_defaults.merge(attrs)

        # Auto-create nodes referenced in edges
        node_ids.each { |nid| ensure_node_exists(nid) }

        # Create edges for each consecutive pair
        node_ids.each_cons(2) do |a, b|
          @edges << Edge.new(a, b, merged_attrs)
        end
      end

      def parse_attr_block
        expect(:LBRACKET)
        attrs = {}

        unless peek_type == :RBRACKET
          key, value = parse_attr
          attrs[key] = value

          while peek_type == :COMMA
            consume # consume ','
            break if peek_type == :RBRACKET

            key, value = parse_attr
            attrs[key] = value
          end
        end

        expect(:RBRACKET)
        attrs
      end

      def parse_attr
        key = parse_key
        expect(:EQUALS)
        value = parse_value
        [key, value]
      end

      def parse_key
        parts = [expect_identifier]

        while peek_type == :DOT
          consume # consume '.'
          parts << expect_identifier
        end

        parts.join(".")
      end

      def parse_value
        case peek_type
        when :STRING
          token = consume
          token.value
        when :INTEGER
          token = consume
          token.value.to_s
        when :FLOAT
          token = consume
          token.value.to_s
        when :BOOLEAN
          token = consume
          token.value
        when :IDENTIFIER
          token = consume
          token.value
        else
          raise_parse_error("Expected a value, got #{peek_type} (#{peek_value.inspect})")
        end
      end

      def parse_graph_attr_decl_tokens
        id = expect_identifier
        expect(:EQUALS)
        value = parse_value
        consume_optional(:SEMICOLON)
        [id, value]
      end

      def register_node(id, explicit_attrs)
        merged = @node_defaults.merge(explicit_attrs)
        if @nodes.key?(id)
          # Merge new attrs onto existing node, explicit attrs win
          existing_attrs = @nodes[id].attrs
          @nodes[id] = Node.new(id, existing_attrs.merge(merged))
        else
          @nodes[id] = Node.new(id, merged)
        end
      end

      def ensure_node_exists(id)
        return if @nodes.key?(id)

        @nodes[id] = Node.new(id, @node_defaults.dup)
      end

      def expect(type)
        token = current_token
        if token.type != type
          raise_parse_error("Expected #{type}, got #{token.type} (#{token.value.inspect})")
        end
        @pos += 1
        token
      end

      def expect_identifier
        token = current_token
        unless token.type == :IDENTIFIER || keyword_usable_as_id?(token.type)
          raise_parse_error("Expected identifier, got #{token.type} (#{token.value.inspect})")
        end
        @pos += 1
        token.value
      end

      def keyword_usable_as_id?(type)
        # In DOT, keywords like 'graph', 'node', 'edge' can also be identifiers
        # in certain contexts, but for Attractor we only allow bare IDENTIFIER tokens
        # and the graph name context. We do NOT allow keywords as node IDs.
        false
      end

      def consume
        token = current_token
        @pos += 1
        token
      end

      def consume_optional(type)
        if peek_type == type
          @pos += 1
          true
        else
          false
        end
      end

      def current_token
        @tokens[@pos] || Token.new(type: :EOF, value: nil, line: 0, column: 0)
      end

      def peek_type
        current_token.type
      end

      def peek_value
        current_token.value
      end

      def peek_type_at(offset)
        token = @tokens[@pos + offset]
        token ? token.type : :EOF
      end

      def looks_like_edge?
        # Scan forward from current position to see if this is an edge statement
        # Look for IDENTIFIER = ... vs IDENTIFIER -> ...
        i = @pos + 1
        # Skip past dots for qualified identifiers
        while i < @tokens.length && @tokens[i].type == :DOT
          i += 1
          i += 1 if i < @tokens.length # skip the identifier after dot
        end
        return false if i >= @tokens.length

        @tokens[i].type == :ARROW
      end

      def raise_parse_error(message)
        token = current_token
        raise ParseError.new(
          message,
          line: token.line,
          column: token.column,
          source_line: @source_lines[token.line - 1]
        )
      end
    end
  end
end
