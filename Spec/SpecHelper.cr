require "spec"
require "../Source/Quartz"

class FSpecUser < Quartz::AModel
  field name : String
  field age  : Int32 = 18
end

class FSpecPost < Quartz::AModel
  field title : String
end

class FSpecEmpty < Quartz::AModel
end

class FSpecAdmin < FSpecUser
  field role : String = "staff"
end

abstract class FSpecTimestamped < Quartz::AModel
  field created_at : String = "now"
end

class FSpecArticle < FSpecTimestamped
  field title : String
end

def quartz_spec_reset : Nil
  FSpecUser .objects.clear
  FSpecPost.objects.clear
  FSpecEmpty.objects.clear
  FSpecAdmin.objects.clear
  FSpecArticle.objects.clear
end

# Compiles `body` (with the Quartz library on the require path)
# and returns the compiler output
# used to assert the `field` macro's compile-time guards.
def quartz_compile( body : String ) : { output: String, success: Bool }
  source_dir = Path[__DIR__].parent.join("Source").to_s
  crystal_path = "#{source_dir}:#{`crystal env CRYSTAL_PATH`.strip}"
  file = File.tempfile("quartz_compile_spec", ".cr") do |f|
    f << "require \"Quartz\"\n" << body
  end
  output = IO::Memory.new
  status = Process.run(
    "crystal",
    ["build", "--no-codegen", file.path],
    env: {"CRYSTAL_PATH" => crystal_path},
    output: output,
    error: output,
  )
  {output: output.to_s, success: status.success?}
ensure
  file.try(&.delete)
end
