# frozen_string_literal: true

require "time"

module Quartz
  class FStopWatch
    def initialize = @t0 = now
    def elapsed = now - @t0
    def elapsed_human = format("%.3fs", elapsed)

    def self.measure
      sw = new
      result = yield
      [result, sw.elapsed]
    end

    private def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
