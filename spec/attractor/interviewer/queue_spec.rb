# frozen_string_literal: true

RSpec.describe Attractor::Interviewer::Queue do
  let(:question) { Attractor::Question.new(text: "Continue?", type: Attractor::QuestionType::YES_NO) }

  describe "#ask" do
    it "returns answers in order" do
      first = Attractor::Answer.new(value: Attractor::AnswerValue::YES)
      second = Attractor::Answer.new(value: Attractor::AnswerValue::NO)
      interviewer = described_class.new(answers: [first, second])

      expect(interviewer.ask(question).value).to eq(Attractor::AnswerValue::YES)
      expect(interviewer.ask(question).value).to eq(Attractor::AnswerValue::NO)
    end

    it "returns SKIPPED when queue is empty" do
      interviewer = described_class.new(answers: [])
      answer = interviewer.ask(question)
      expect(answer.value).to eq(Attractor::AnswerValue::SKIPPED)
    end

    it "returns SKIPPED after exhausting all queued answers" do
      single = Attractor::Answer.new(value: Attractor::AnswerValue::YES)
      interviewer = described_class.new(answers: [single])

      interviewer.ask(question)
      answer = interviewer.ask(question)
      expect(answer.value).to eq(Attractor::AnswerValue::SKIPPED)
    end

    it "does not mutate the original array" do
      answers = [Attractor::Answer.new(value: Attractor::AnswerValue::YES)]
      original_size = answers.size
      interviewer = described_class.new(answers: answers)

      interviewer.ask(question)
      expect(answers.size).to eq(original_size)
    end
  end
end
