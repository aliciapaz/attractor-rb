# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::Stylesheet::Parser do
  describe ".parse" do
    it "returns an empty array for nil input" do
      expect(described_class.parse(nil)).to eq([])
    end

    it "returns an empty array for empty string" do
      expect(described_class.parse("")).to eq([])
    end

    it "parses a universal selector rule" do
      source = "* { llm_model: claude-sonnet-4-5; }"
      rules = described_class.parse(source)

      expect(rules.size).to eq(1)
      expect(rules[0].selector).to eq("*")
      expect(rules[0].declarations).to eq({"llm_model" => "claude-sonnet-4-5"})
    end

    it "parses a class selector rule" do
      source = ".code { llm_model: claude-opus-4-6; llm_provider: anthropic; }"
      rules = described_class.parse(source)

      expect(rules.size).to eq(1)
      expect(rules[0].selector).to eq(".code")
      expect(rules[0].declarations["llm_model"]).to eq("claude-opus-4-6")
      expect(rules[0].declarations["llm_provider"]).to eq("anthropic")
    end

    it "parses an ID selector rule" do
      source = "#review { reasoning_effort: high; }"
      rules = described_class.parse(source)

      expect(rules.size).to eq(1)
      expect(rules[0].selector).to eq("#review")
      expect(rules[0].declarations["reasoning_effort"]).to eq("high")
    end

    it "parses multiple rules" do
      source = <<~CSS
        * { llm_model: gpt-4; }
        .fast { llm_model: gpt-3.5; }
        #special { llm_model: claude-opus-4-6; }
      CSS
      rules = described_class.parse(source)

      expect(rules.size).to eq(3)
    end

    it "handles rules without trailing semicolons" do
      source = "* { llm_model: gpt-4 }"
      rules = described_class.parse(source)

      expect(rules.size).to eq(1)
      expect(rules[0].declarations["llm_model"]).to eq("gpt-4")
    end

    it "raises on invalid selector" do
      source = "invalid! { llm_model: gpt-4; }"
      expect { described_class.parse(source) }.to raise_error(Attractor::Stylesheet::Parser::ParseError)
    end
  end

  describe ".valid?" do
    it "returns true for valid source" do
      expect(described_class.valid?("* { llm_model: gpt-4; }")).to be true
    end

    it "returns true for nil" do
      expect(described_class.valid?(nil)).to be true
    end

    it "returns false for invalid source" do
      expect(described_class.valid?("invalid! { }")).to be false
    end
  end

  describe "specificity ordering" do
    it "assigns specificity 0 to universal selector" do
      rules = described_class.parse("* { llm_model: x; }")
      expect(rules[0].specificity).to eq(0)
    end

    it "assigns specificity 1 to class selector" do
      rules = described_class.parse(".code { llm_model: x; }")
      expect(rules[0].specificity).to eq(1)
    end

    it "assigns specificity 2 to ID selector" do
      rules = described_class.parse("#node { llm_model: x; }")
      expect(rules[0].specificity).to eq(2)
    end

    it "sorts rules correctly by specificity" do
      source = <<~CSS
        * { llm_model: a; }
        #node { llm_model: c; }
        .code { llm_model: b; }
      CSS
      rules = described_class.parse(source)
      sorted = rules.sort_by(&:specificity)

      expect(sorted.map(&:selector)).to eq(["*", ".code", "#node"])
    end
  end
end
