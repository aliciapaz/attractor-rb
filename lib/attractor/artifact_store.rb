# frozen_string_literal: true

require "concurrent"

module Attractor
  class ArtifactStore
    FILE_BACKING_THRESHOLD = 100 * 1024 # 100KB

    ArtifactInfo = Data.define(:id, :name, :size_bytes, :stored_at, :is_file_backed)

    def initialize(base_dir: nil)
      @artifacts = {}
      @lock = Concurrent::ReadWriteLock.new
      @base_dir = base_dir
    end

    def store(artifact_id, name, data)
      serialized = data.is_a?(String) ? data : JSON.generate(data)
      size = serialized.bytesize
      file_backed = size > FILE_BACKING_THRESHOLD && @base_dir

      if file_backed
        dir = File.join(@base_dir, "artifacts")
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "#{artifact_id}.json")
        File.write(path, serialized)
        stored_data = path
      else
        stored_data = data
      end

      info = ArtifactInfo.new(
        id: artifact_id, name: name, size_bytes: size,
        stored_at: Time.now.iso8601, is_file_backed: file_backed
      )

      @lock.with_write_lock { @artifacts[artifact_id] = [info, stored_data] }
      info
    end

    def retrieve(artifact_id)
      entry = @lock.with_read_lock { @artifacts[artifact_id] }
      raise Error, "Artifact not found: #{artifact_id}" unless entry

      info, data = entry
      info.is_file_backed ? JSON.parse(File.read(data)) : data
    end

    def has?(artifact_id)
      @lock.with_read_lock { @artifacts.key?(artifact_id) }
    end

    def list
      @lock.with_read_lock { @artifacts.values.map(&:first) }
    end

    def remove(artifact_id)
      @lock.with_write_lock { @artifacts.delete(artifact_id) }
    end

    def clear
      @lock.with_write_lock { @artifacts.clear }
    end
  end
end
