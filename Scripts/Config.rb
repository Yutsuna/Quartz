# frozen_string_literal: true

require "etc"

module Quartz
  FConfig = Data.define(
    # --- Sources -----------------------------------------------------------
    :src_dir,          # Root directory for Crystal sources
    :source_glob,      # Glob used to discover .cr files
    :entrypoint,       # Entry point passed to `crystal build`
    :manifests,        # Additional files included in the hash (deps)

    # --- Output ------------------------------------------------------------
    :output_dir,       # Final binary output directory
    :binary_name,      # Final binary name

    # --- Cache -------------------------------------------------------------
    :cache_file,       # Top-level cache metadata (JSON)
    :crystal_cache_dir, # CRYSTAL_CACHE_DIR -> reuse Crystal .o files

    # --- Parallelism ------------------------------------------------------
    :nproc,            # Number of cores (Etc.nprocessors by default)
    :hash_workers,     # Threads used to hash sources

    # --- Compiler / Linker ------------------------------------------------
    :crystal_bin,      # Compiler binary
    :mold_bin,         # mold linker binary
    :release,          # Default --release build?
    :extra_crystal_args # Additional arguments passed through as-is
  ) do
    def binary_path = File.join(output_dir, binary_name)

    def fingerprint = [entrypoint, release, extra_crystal_args, RUBY_VERSION].inspect
  end

  module FConfigLoader
    module_function

    def env(key, default) = ENV.fetch("QUARTZ_#{key}", default)

    def env_bool(key, default)
      raw = ENV["QUARTZ_#{key}"]
      raw.nil? ? default : %w[1 true yes on].include?(raw.downcase)
    end

    def env_int(key, default) = Integer(ENV.fetch("QUARTZ_#{key}", default))

    def load
      nproc = env_int("NPROC", Etc.nprocessors)

      FConfig.new(
        src_dir: env("SRC_DIR", "Source"),
        source_glob: env("SOURCE_GLOB", "**/*.cr"),
        entrypoint: env("ENTRYPOINT", File.join(env("SRC_DIR", "Source"), "Quartz.cr")),
        manifests: env("MANIFESTS", "shard.yml,shard.lock").split(",").map(&:strip),
        output_dir: env("OUTPUT_DIR", "bin"),
        binary_name: env("BINARY_NAME", File.basename(Dir.pwd)),
        cache_file: env("CACHE_FILE", ".crystal_build_cache.json"),
        crystal_cache_dir: env("CRYSTAL_CACHE_DIR", File.join(Dir.pwd, ".crystal_cache")),
        nproc: nproc,
        hash_workers: env_int("HASH_WORKERS", nproc),
        crystal_bin: env("CRYSTAL_BIN", "crystal"),
        mold_bin: env("MOLD_BIN", "mold"),
        release: env_bool("RELEASE", false),
        extra_crystal_args: env("EXTRA_ARGS", "").split(" "),
      )
    end
  end
end
