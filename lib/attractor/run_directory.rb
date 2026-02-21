# frozen_string_literal: true

module Attractor
  module RunDirectory
    def self.create(logs_root, node_id)
      dir = File.join(logs_root, node_id)
      FileUtils.mkdir_p(dir)
      dir
    end

    def self.write_status(logs_root, node_id, outcome)
      dir = create(logs_root, node_id)
      path = File.join(dir, "status.json")
      File.write(path, JSON.pretty_generate(outcome.to_h))
    end

    def self.write_prompt(logs_root, node_id, prompt)
      dir = create(logs_root, node_id)
      File.write(File.join(dir, "prompt.md"), prompt)
    end

    def self.write_response(logs_root, node_id, response)
      dir = create(logs_root, node_id)
      File.write(File.join(dir, "response.md"), response)
    end

    def self.write_manifest(logs_root, graph)
      manifest = {
        name: graph.name,
        goal: graph.goal,
        started_at: Time.now.iso8601
      }
      File.write(
        File.join(logs_root, "manifest.json"),
        JSON.pretty_generate(manifest)
      )
    end
  end
end
