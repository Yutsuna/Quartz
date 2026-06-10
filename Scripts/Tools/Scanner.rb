# frozen_string_literal: true

require "digest"

module Quartz
  class FSourceScanner
    def initialize(config)
      @config = config
    end

    def files
      sources = Dir.glob(File.join(@config.src_dir, @config.source_glob)).select { |path| File.file?(path) }
      manifests = @config.manifests.select { |path| File.file?(path) }
      (sources + manifests).sort
    end

    def digest(file_list)
      queue = Queue.new
      file_list.each_with_index { |path, idx| queue << [idx, path] }
      results = Array.new(file_list.size)

      workers = [@config.hash_workers, file_list.size].min.clamp(1, 64)
      threads = workers.times.map do
        Thread.new do
          loop do
            idx, path = begin
                queue.pop true
              rescue ThreadError
                break
              end
            stat = File.stat path
            results[idx] = Digest::SHA256.hexdigest("#{path}|#{stat.size}|#{stat.mtime.to_f}|#{Digest::SHA256.file(path).hexdigest}")
          end
        end
      end

      threads.each(&:join)

      reducer = Digest::SHA256.new
      reducer << @config.fingerprint
      results.each { |digest| reducer << digest }
      reducer.hexdigest
    end
  end
end
