module Quartz
  module Toolchain
    module_function

    def which(bin)
      return bin if File.executable? bin and !File.directory? bin

      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
        candidate = File.join(dir, bin)
        return candidate if File.executable?(candidate) && !File.directory?(candidate)
      end

      nil
    end
  end
end
