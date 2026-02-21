# frozen_string_literal: true

RSpec.describe Attractor::Interviewer::AutoApprove do
  subject(:interviewer) { described_class.new }

  describe "#ask" do
    context "with YES_NO question" do
      let(:question) { Attractor::Question.new(text: "Deploy?", type: Attractor::QuestionType::YES_NO) }

      it "returns YES" do
        answer = interviewer.ask(question)
        expect(answer.value).to eq(Attractor::AnswerValue::YES)
      end
    end

    context "with CONFIRMATION question" do
      let(:question) { Attractor::Question.new(text: "Confirm?", type: Attractor::QuestionType::CONFIRMATION) }

      it "returns YES" do
        answer = interviewer.ask(question)
        expect(answer.value).to eq(Attractor::AnswerValue::YES)
      end
    end

    context "with MULTIPLE_CHOICE question" do
      let(:options) do
        [
          Attractor::Option.new(key: "A", label: "Approve"),
          Attractor::Option.new(key: "R", label: "Reject")
        ]
      end
      let(:question) do
        Attractor::Question.new(
          text: "Review?",
          type: Attractor::QuestionType::MULTIPLE_CHOICE,
          options: options
        )
      end

      it "selects the first option" do
        answer = interviewer.ask(question)
        expect(answer.value).to eq("A")
      end

      it "includes the selected option" do
        answer = interviewer.ask(question)
        expect(answer.selected_option).to eq(options.first)
      end
    end

    context "with MULTIPLE_CHOICE question with no options" do
      let(:question) do
        Attractor::Question.new(
          text: "Choose?",
          type: Attractor::QuestionType::MULTIPLE_CHOICE,
          options: []
        )
      end

      it "returns auto-approved" do
        answer = interviewer.ask(question)
        expect(answer.value).to eq("auto-approved")
      end
    end

    context "with FREEFORM question" do
      let(:question) { Attractor::Question.new(text: "Describe:", type: Attractor::QuestionType::FREEFORM) }

      it "returns auto-approved" do
        answer = interviewer.ask(question)
        expect(answer.value).to eq("auto-approved")
      end
    end
  end
end
