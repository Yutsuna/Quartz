# frozen_string_literal: true

module Quartz
  module EAnsiColor
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"
    RESET = "\033[0m"
    GREY = "\033[90m"
    BOLD = "\033[1m"
  end

  module FLog
    module_function

    def log(message, prefix: "Builder", color: EAnsiColor::CYAN)
      tag = "#{color}#{EAnsiColor::BOLD}[#{prefix}]#{EAnsiColor::RESET}"
      $stdout.puts("#{tag} #{message}")
      $stdout.flush
    end

    def ok(message) = log(message, prefix: "  OK  ", color: EAnsiColor::GREEN)
    def warn(message) = log(message, prefix: " WARN ", color: EAnsiColor::YELLOW)
    def error(message) = log(message, prefix: " ERR  ", color: EAnsiColor::RED)
    def step(message) = log(message, prefix: "  >>  ", color: EAnsiColor::BLUE)

    def info(message)
      $stdout.puts("#{EAnsiColor::GREY}#{message}#{EAnsiColor::RESET}")
      $stdout.flush
    end

    def command(message)
      $stdout.print("\r#{EAnsiColor::GREY}#{message}#{EAnsiColor::RESET}")
      $stdout.flush
    end
  end
end
