# frozen_string_literal: true

RSpec.describe Attractor::Dot::Lexer do
  def tokenize(source)
    described_class.new(source).tokenize
  end

  def token_types(source)
    tokenize(source).map(&:type)
  end

  def token_values(source)
    tokenize(source).map(&:value)
  end

  describe "#tokenize" do
    it "tokenizes a simple digraph" do
      source = "digraph G { A -> B }"
      types = token_types(source)

      expect(types).to eq([:DIGRAPH, :IDENTIFIER, :LBRACE, :IDENTIFIER, :ARROW, :IDENTIFIER, :RBRACE, :EOF])
    end

    it "returns correct values for identifiers" do
      source = "digraph MyGraph { node_a -> node_b }"
      tokens = tokenize(source)

      expect(tokens[0].value).to eq("digraph")
      expect(tokens[1].value).to eq("MyGraph")
      expect(tokens[3].value).to eq("node_a")
      expect(tokens[5].value).to eq("node_b")
    end

    it "tokenizes keywords case-sensitively" do
      source = "digraph graph node edge subgraph"
      types = token_types(source)
      expect(types).to eq([:DIGRAPH, :GRAPH, :NODE, :EDGE, :SUBGRAPH, :EOF])
    end

    it "treats capitalized keywords as identifiers" do
      source = "digraph G { Digraph Node Edge }"
      tokens = tokenize(source)
      digraph_token = tokens.find { |t| t.value == "Digraph" }
      expect(digraph_token.type).to eq(:IDENTIFIER)
    end

    it "tokenizes attribute blocks" do
      source = 'digraph G { A [label="Hello", shape=box] }'
      types = token_types(source)

      expect(types).to eq([
        :DIGRAPH, :IDENTIFIER, :LBRACE,
        :IDENTIFIER, :LBRACKET,
        :IDENTIFIER, :EQUALS, :STRING, :COMMA,
        :IDENTIFIER, :EQUALS, :IDENTIFIER,
        :RBRACKET,
        :RBRACE, :EOF
      ])
    end

    it "tokenizes semicolons" do
      source = "digraph G { A; B; }"
      types = token_types(source)
      expect(types).to include(:SEMICOLON)
    end

    it "tokenizes the dot operator" do
      source = 'digraph G { a.b.c = "val" }'
      types = token_types(source)
      expect(types).to include(:DOT)
    end
  end

  describe "string tokens" do
    it "handles simple strings" do
      tokens = tokenize('"hello world"')
      str = tokens.find { |t| t.type == :STRING }
      expect(str.value).to eq("hello world")
    end

    it "handles escaped quotes" do
      tokens = tokenize('"say \\"hi\\""')
      str = tokens.find { |t| t.type == :STRING }
      expect(str.value).to eq('say "hi"')
    end

    it "handles escaped newlines" do
      tokens = tokenize('"line1\\nline2"')
      str = tokens.find { |t| t.type == :STRING }
      expect(str.value).to eq("line1\nline2")
    end

    it "handles escaped tabs" do
      tokens = tokenize('"col1\\tcol2"')
      str = tokens.find { |t| t.type == :STRING }
      expect(str.value).to eq("col1\tcol2")
    end

    it "handles escaped backslashes" do
      tokens = tokenize('"path\\\\file"')
      str = tokens.find { |t| t.type == :STRING }
      expect(str.value).to eq("path\\file")
    end

    it "raises on unterminated string" do
      expect { tokenize('"unterminated') }.to raise_error(Attractor::Dot::ParseError, /Unterminated string/)
    end
  end

  describe "numeric tokens" do
    it "tokenizes integers" do
      tokens = tokenize("42")
      int = tokens.find { |t| t.type == :INTEGER }
      expect(int.value).to eq(42)
    end

    it "tokenizes negative integers" do
      tokens = tokenize("-7")
      int = tokens.find { |t| t.type == :INTEGER }
      expect(int.value).to eq(-7)
    end

    it "tokenizes floats" do
      tokens = tokenize("3.14")
      flt = tokens.find { |t| t.type == :FLOAT }
      expect(flt.value).to eq(3.14)
    end

    it "tokenizes negative floats" do
      tokens = tokenize("-0.5")
      flt = tokens.find { |t| t.type == :FLOAT }
      expect(flt.value).to eq(-0.5)
    end

    it "tokenizes floats starting with dot" do
      tokens = tokenize(".75")
      flt = tokens.find { |t| t.type == :FLOAT }
      expect(flt.value).to eq(0.75)
    end
  end

  describe "boolean tokens" do
    it "tokenizes true" do
      tokens = tokenize("true")
      bool = tokens.find { |t| t.type == :BOOLEAN }
      expect(bool.value).to eq("true")
    end

    it "tokenizes false" do
      tokens = tokenize("false")
      bool = tokens.find { |t| t.type == :BOOLEAN }
      expect(bool.value).to eq("false")
    end
  end

  describe "comments" do
    it "strips line comments" do
      source = <<~DOT
        digraph G { // this is a comment
          A -> B
        }
      DOT
      types = token_types(source)
      expect(types).to eq([:DIGRAPH, :IDENTIFIER, :LBRACE, :IDENTIFIER, :ARROW, :IDENTIFIER, :RBRACE, :EOF])
    end

    it "strips block comments" do
      source = "digraph G { /* block comment */ A -> B }"
      types = token_types(source)
      expect(types).to eq([:DIGRAPH, :IDENTIFIER, :LBRACE, :IDENTIFIER, :ARROW, :IDENTIFIER, :RBRACE, :EOF])
    end

    it "strips multi-line block comments" do
      source = <<~DOT
        digraph G {
          /* this is
             a multi-line
             comment */
          A -> B
        }
      DOT
      types = token_types(source)
      expect(types).to eq([:DIGRAPH, :IDENTIFIER, :LBRACE, :IDENTIFIER, :ARROW, :IDENTIFIER, :RBRACE, :EOF])
    end

    it "does not strip comments inside strings" do
      source = 'digraph G { A [label="has // comment"] }'
      tokens = tokenize(source)
      str = tokens.find { |t| t.type == :STRING }
      expect(str.value).to eq("has // comment")
    end
  end

  describe "error on undirected edges" do
    it "raises ParseError for --" do
      source = "digraph G { A -- B }"
      expect { tokenize(source) }.to raise_error(
        Attractor::Dot::ParseError,
        /Undirected edges.*not supported.*use directed/
      )
    end
  end

  describe "line and column tracking" do
    it "tracks line numbers" do
      source = "digraph G {\n  A\n  B\n}"
      tokens = tokenize(source)
      a_token = tokens.find { |t| t.value == "A" }
      b_token = tokens.find { |t| t.value == "B" }

      expect(a_token.line).to eq(2)
      expect(b_token.line).to eq(3)
    end

    it "tracks column numbers" do
      source = "digraph G {"
      tokens = tokenize(source)

      expect(tokens[0].column).to eq(1)  # digraph
      expect(tokens[1].column).to eq(9)  # G
      expect(tokens[2].column).to eq(11) # {
    end
  end

  describe "duration values as strings" do
    it "tokenizes duration-like values inside strings" do
      source = '"900s"'
      tokens = tokenize(source)
      str = tokens.find { |t| t.type == :STRING }
      expect(str.value).to eq("900s")
      expect(str.type).to eq(:STRING)
    end
  end
end
