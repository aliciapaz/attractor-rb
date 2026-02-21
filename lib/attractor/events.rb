# frozen_string_literal: true

module Attractor
  module Events
    PipelineStarted = Data.define(:name, :id)
    PipelineCompleted = Data.define(:duration, :artifact_count)
    PipelineFailed = Data.define(:error, :duration)

    StageStarted = Data.define(:name, :index)
    StageCompleted = Data.define(:name, :index, :duration)
    StageFailed = Data.define(:name, :index, :error, :will_retry)
    StageRetrying = Data.define(:name, :index, :attempt, :delay)

    ParallelStarted = Data.define(:branch_count)
    ParallelBranchStarted = Data.define(:branch, :index)
    ParallelBranchCompleted = Data.define(:branch, :index, :duration, :success)
    ParallelCompleted = Data.define(:duration, :success_count, :failure_count)

    InterviewStarted = Data.define(:question, :stage)
    InterviewCompleted = Data.define(:question, :answer, :duration)
    InterviewTimeout = Data.define(:question, :stage, :duration)

    CheckpointSaved = Data.define(:node_id)
  end
end
