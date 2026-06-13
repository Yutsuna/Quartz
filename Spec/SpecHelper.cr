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

# The `FSpec` prefix makes the underscored class name (`f_spec_author_id`)
# differ from the `belongs_to author` foreign key, so the fixtures pin the
# foreign key explicitly. The bare-default derivation is covered by a
# `quartz_compile` test with single-word class names in RelationsSpec.
class FSpecAuthor < Quartz::AModel
  field name : String
  has_many books : FSpecBook, foreign_key: author_id
end

class FSpecBook < Quartz::AModel
  field title : String
  belongs_to author : FSpecAuthor
end

class FSpecLibrary < Quartz::AModel
  field name : String
  has_many books : FSpecShelvedBook, foreign_key: shelf_id
end

class FSpecShelvedBook < Quartz::AModel
  field title : String
  field shelf_id : UInt64 = 0_u64
end

class FSpecEbook < FSpecBook
  field format : String = "epub"
end

def quartz_spec_reset : Nil
  FSpecUser .objects.clear
  FSpecPost.objects.clear
  FSpecEmpty.objects.clear
  FSpecAdmin.objects.clear
  FSpecArticle.objects.clear
  FSpecAuthor.objects.clear
  FSpecBook.objects.clear
  FSpecLibrary.objects.clear
  FSpecShelvedBook.objects.clear
  FSpecEbook.objects.clear
end

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
