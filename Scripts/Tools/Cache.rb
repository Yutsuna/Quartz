require "json"

module Quartz
  class FCacheStore
    def initialize(path)
      @path = path
    end

    def read
      return {} unless File.file? @path
      JSON.parse(File.read(@path))
    rescue JSON::ParserError
      FLog.warn("Corrupted cache file at #{@path}, regenerating.")
      {}
    end

    def write(payload)
      tmp = "#{@path}.tmp.#{Process.pid}"
      File.write(tmp, JSON.pretty_generate(payload))
      File.rename(tmp, @path)
    end
  end
end
