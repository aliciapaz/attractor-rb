# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::Condition::Evaluator do
  def build_outcome(status:, preferred_label: "")
    Attractor::Outcome.new(status: status, preferred_label: preferred_label)
  end

  def build_context(values = {})
    Attractor::Context.new(values: values)
  end

  describe ".evaluate" do
    it "returns true for empty condition" do
      outcome = build_outcome(status: "success")
      context = build_context
      expect(described_class.evaluate("", outcome, context)).to be true
    end

    it "returns true for nil condition" do
      outcome = build_outcome(status: "success")
      context = build_context
      expect(described_class.evaluate(nil, outcome, context)).to be true
    end

    it "matches outcome=success with SUCCESS outcome" do
      outcome = build_outcome(status: "success")
      context = build_context
      expect(described_class.evaluate("outcome=success", outcome, context)).to be true
    end

    it "does not match outcome=success with FAIL outcome" do
      outcome = build_outcome(status: "fail")
      context = build_context
      expect(described_class.evaluate("outcome=success", outcome, context)).to be false
    end

    it "matches outcome!=fail with SUCCESS outcome" do
      outcome = build_outcome(status: "success")
      context = build_context
      expect(described_class.evaluate("outcome!=fail", outcome, context)).to be true
    end

    it "does not match outcome!=fail with FAIL outcome" do
      outcome = build_outcome(status: "fail")
      context = build_context
      expect(described_class.evaluate("outcome!=fail", outcome, context)).to be false
    end

    it "matches context.x=y when context has x=y" do
      outcome = build_outcome(status: "success")
      context = build_context("x" => "y")
      expect(described_class.evaluate("context.x=y", outcome, context)).to be true
    end

    it "does not match context.x=y when context has x=z" do
      outcome = build_outcome(status: "success")
      context = build_context("x" => "z")
      expect(described_class.evaluate("context.x=y", outcome, context)).to be false
    end

    it "matches conjunction when both clauses match" do
      outcome = build_outcome(status: "success")
      context = build_context("x" => "y")
      expect(described_class.evaluate("outcome=success && context.x=y", outcome, context)).to be true
    end

    it "does not match conjunction when one clause fails" do
      outcome = build_outcome(status: "success")
      context = build_context("x" => "z")
      expect(described_class.evaluate("outcome=success && context.x=y", outcome, context)).to be false
    end

    it "treats missing context key as empty string" do
      outcome = build_outcome(status: "success")
      context = build_context
      expect(described_class.evaluate("context.missing=", outcome, context)).to be true
    end

    it "missing context key does not match non-empty value" do
      outcome = build_outcome(status: "success")
      context = build_context
      expect(described_class.evaluate("context.missing=something", outcome, context)).to be false
    end

    it "matches preferred_label" do
      outcome = build_outcome(status: "success", preferred_label: "Fix")
      context = build_context
      expect(described_class.evaluate("preferred_label=Fix", outcome, context)).to be true
    end

    it "does not match wrong preferred_label" do
      outcome = build_outcome(status: "success", preferred_label: "Ship")
      context = build_context
      expect(described_class.evaluate("preferred_label=Fix", outcome, context)).to be false
    end

    it "resolves context keys with context. prefix trying bare key" do
      outcome = build_outcome(status: "success")
      context = build_context("tests_passed" => "true")
      expect(described_class.evaluate("context.tests_passed=true", outcome, context)).to be true
    end

    it "resolves unqualified keys as direct context lookup" do
      outcome = build_outcome(status: "success")
      context = build_context("my_flag" => "on")
      expect(described_class.evaluate("my_flag=on", outcome, context)).to be true
    end

    it "works with hash-based context" do
      outcome = build_outcome(status: "success")
      context = {"x" => "y"}
      expect(described_class.evaluate("context.x=y", outcome, context)).to be true
    end
  end
end
