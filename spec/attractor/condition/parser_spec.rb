# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::Condition::Parser do
  describe ".parse" do
    it "returns empty array for nil" do
      expect(described_class.parse(nil)).to eq([])
    end

    it "returns empty array for empty string" do
      expect(described_class.parse("")).to eq([])
    end

    it "returns empty array for whitespace-only string" do
      expect(described_class.parse("   ")).to eq([])
    end

    it "parses a simple equals clause" do
      clauses = described_class.parse("outcome=success")
      expect(clauses.size).to eq(1)
      expect(clauses.first.key).to eq("outcome")
      expect(clauses.first.operator).to eq("=")
      expect(clauses.first.value).to eq("success")
    end

    it "parses a not-equals clause" do
      clauses = described_class.parse("outcome!=fail")
      expect(clauses.size).to eq(1)
      expect(clauses.first.key).to eq("outcome")
      expect(clauses.first.operator).to eq("!=")
      expect(clauses.first.value).to eq("fail")
    end

    it "parses multiple clauses joined by &&" do
      clauses = described_class.parse("outcome=success && context.x=y")
      expect(clauses.size).to eq(2)
      expect(clauses[0].key).to eq("outcome")
      expect(clauses[0].value).to eq("success")
      expect(clauses[1].key).to eq("context.x")
      expect(clauses[1].value).to eq("y")
    end

    it "handles whitespace around clauses" do
      clauses = described_class.parse("  outcome = success  &&  context.x = y  ")
      expect(clauses.size).to eq(2)
      expect(clauses[0].key).to eq("outcome")
      expect(clauses[0].value).to eq("success")
    end

    it "parses context-prefixed keys" do
      clauses = described_class.parse("context.tests_passed=true")
      expect(clauses.first.key).to eq("context.tests_passed")
      expect(clauses.first.value).to eq("true")
    end

    it "parses preferred_label clause" do
      clauses = described_class.parse("preferred_label=Fix")
      expect(clauses.first.key).to eq("preferred_label")
      expect(clauses.first.value).to eq("Fix")
    end
  end

  describe ".valid?" do
    it "returns true for empty string" do
      expect(described_class.valid?("")).to be true
    end

    it "returns true for nil" do
      expect(described_class.valid?(nil)).to be true
    end

    it "returns true for valid equals expression" do
      expect(described_class.valid?("outcome=success")).to be true
    end

    it "returns true for valid not-equals expression" do
      expect(described_class.valid?("outcome!=fail")).to be true
    end

    it "returns true for valid conjunction" do
      expect(described_class.valid?("outcome=success && context.x=y")).to be true
    end

    it "returns false for standalone &&" do
      expect(described_class.valid?("&&")).to be false
    end

    it "returns false for missing key" do
      expect(described_class.valid?("=value")).to be false
    end
  end
end
