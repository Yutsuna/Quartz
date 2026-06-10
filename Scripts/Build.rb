#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "fileutils"
require "open3"

require_relative "Config"

require_relative "Tools/Cache"
require_relative "Tools/Log"
require_relative "Tools/Scanner"
require_relative "Tools/StopWatch"
require_relative "Tools/Toolchain"

module Quartz
  FailureStatus = Data.define(:exitstatus) do
    def success? = false
  end

  class FBuilder
    def initialize(config, force: false, run_after: false, passthrough: [])
      @config = config
      @force = force
      @run_after = run_after
      @passthrough = passthrough
      @cache = FCacheStore.new(config.cache_file)
      @scanner = FSourceScanner.new(config)
    end

    def call
      total = FStopWatch.new
      FLog.log("Quartz Builder — #{@config.nproc} cores detected (Etc.nprocessors)")

      digest = compute_digest or return 1
      return finish_cached(total) if cache_hit?(digest)

      status = compile
      if status.success?
        persist_cache(digest)
        FLog.ok("Build completed in #{total.elapsed_human} -> #{@config.binary_path}")
        return run_binary if @run_after
        0
      else
        FLog.error("Build failed (exit #{status.exitstatus}) after #{total.elapsed_human}")
        status.exitstatus || 1
      end
    end

    private

    def compute_digest
      FLog.step("Scanning sources (#{@config.src_dir}/#{@config.source_glob})...")
      files, scan_time = FStopWatch.measure { @scanner.files }

      if files.empty?
        FLog.error("No source files found in #{@config.src_dir.inspect}.")
        return nil
      end

      digest, hash_time = FStopWatch.measure { @scanner.digest(files) }
      FLog.info("  #{files.size} files scanned in #{format("%.3fs", scan_time)}, " \
      "SHA256 hash in #{format("%.3fs", hash_time)} " \
      "(#{[@config.hash_workers, files.size].min} workers)")
      FLog.info("  global hash: #{digest[0, 16]}…")
      digest
    end

    def cache_hit?(digest)
      return false if @force

      previous = @cache.read
      previous["hash"] == digest && File.executable?(@config.binary_path)
    end

    def finish_cached(total)
      FLog.ok("Cache: No sources changed, binary reused " \
      "(#{@config.binary_path}) in #{total.elapsed_human} ⚡")
      return run_binary if @run_after

      0
    end

    def persist_cache(digest)
      @cache.write(
        "hash" => digest,
        "binary" => @config.binary_path,
        "release" => @config.release,
        "built_at" => Time.now.utc.iso8601,
        "ruby" => RUBY_VERSION,
      )
    end

    def compile
      unless Toolchain.which(@config.crystal_bin)
        FLog.error("Compiler not found: #{@config.crystal_bin.inspect}")
        return FailureStatus.new(exitstatus: 127)
      end

      FileUtils.mkdir_p(@config.output_dir)
      FileUtils.mkdir_p(@config.crystal_cache_dir)

      cmd = build_command
      env = build_env

      FLog.step("Compiling: #{cmd.join(" ")}")
      FLog.info("  CRYSTAL_CACHE_DIR=#{env["CRYSTAL_CACHE_DIR"]} (reusing .o files)")

      status, compile_time = FStopWatch.measure { stream_subprocess(env, cmd) }
      verb = status.success? ? FLog.method(:ok) : FLog.method(:error)
      verb.call("Compilation + linking phase: #{format("%.3fs", compile_time)}")
      status
    end

    def build_command
      cmd = [
        @config.crystal_bin, "build", @config.entrypoint,
        "-o", @config.binary_path,
        "--threads", @config.nproc.to_s,
        "--progress", "--stats",
      ]
      cmd << "--release" if @config.release
      cmd.concat(linker_flags)
      cmd.concat(@config.extra_crystal_args)
      cmd.concat(@passthrough)
      cmd
    end

    def linker_flags
      mold = Toolchain.which(@config.mold_bin)
      if mold
        FLog.step("Linker: mold detected (#{mold}) — multi-threaded linking x#{@config.nproc}")
        ["--link-flags", "-fuse-ld=mold -Wl,--thread-count=#{@config.nproc}"]
      else
        FLog.warn("mold not found — falling back to the system linker (ld). " \
        "Install mold to speed up linking.")
        []
      end
    end

    def build_env
      { "CRYSTAL_CACHE_DIR" => @config.crystal_cache_dir }
    end

    def stream_subprocess(env, cmd)
      stderr_buffer = +""

      status = Open3.popen3(env, *cmd) do |stdin, stdout, stderr, wait|
        stdin.close
        out_t = Thread.new { stdout.each_line { |line| FLog.command("  #{line.chomp}") } }
        err_t = Thread.new { stderr.each_line { |line| stderr_buffer << line } }
        [out_t, err_t].each(&:join)
        wait.value
      end
      $stdout.puts

      unless status.success? || stderr_buffer.empty?
        report_compiler_errors(stderr_buffer)
      end
      status
    rescue Errno::ENOENT => e
      FLog.error("Cannot launch the compiler: #{e.message}")
      FailureStatus.new(exitstatus: 127)
    end

    def report_compiler_errors(buffer)
      FLog.error("Crystal compiler output:")
      buffer.each_line { |line| $stderr.puts("  #{EAnsiColor::RED}│#{EAnsiColor::RESET} #{line.chomp}") }
      $stderr.flush
    end

    def run_binary
      FLog.step("Running #{@config.binary_path}…")
      system(@config.binary_path) ? 0 : ($?.exitstatus || 1)
    end
  end

  module CLI
    module_function

    def call(argv)
      passthrough = []
      if (sep = argv.index("--"))
        passthrough = argv[(sep + 1)..]
        argv = argv[...sep]
      end

      config = FConfigLoader.load
      force = false
      run_after = false
      overrides = {}

      OptionParser.new do |o|
        o.banner = "Usage: build.rb [options] [-- crystal args]"
        o.on("-r", "--release", "Build optimisé (--release)") { overrides[:release] = true }
        o.on("-f", "--force", "Ignorer le cache et recompiler") { force = true }
        o.on("-e", "--entrypoint PATH", "Point d'entrée (défaut: #{config.entrypoint})") { |v| overrides[:entrypoint] = v }
        o.on("-o", "--output NAME", "Nom du binaire (défaut: #{config.binary_name})") { |v| overrides[:binary_name] = v }
        o.on("-x", "--run", "Exécuter le binaire après le build") { run_after = true }
        o.on("-h", "--help", "Afficher cette aide") { puts o; exit 0 }
      end.parse!(argv)

      config = config.with(**overrides) unless overrides.empty?
      FBuilder.new(config, force:, run_after:, passthrough:).call
    end
  end
end

exit(Quartz::CLI.call(ARGV)) if $PROGRAM_NAME == __FILE__
