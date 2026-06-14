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

class FSpecAccount < Quartz::AModel
  field email    : String = ""
  field nickname : String = ""
  field age      : Int32  = 0

  validates email,    presence: true
  validates nickname, length: {min: 2, max: 10}
  validate do |errors|
    errors.add("age", "must be adult") if age < 18
  end
end

class FSpecPremiumAccount < FSpecAccount
  field referral : String = ""
  validates referral, presence: true
end

class FSpecHooked < Quartz::AModel
  field name  : String        = ""
  field trace : Array(String) = [] of String

  before_save   { trace << "before_save" }
  after_save    { trace << "after_save" }
  before_create { trace << "before_create" }
  after_create  { trace << "after_create" }
  before_delete { trace << "before_delete" }
  after_delete  { trace << "after_delete" }
end

class FSpecHookedChild < FSpecHooked
  before_save { trace << "child_before_save" }
end

class FSpecNormalized < Quartz::AModel
  field name : String = ""
  before_save { self.name = name.strip.downcase }
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
  FSpecAccount.objects.clear
  FSpecPremiumAccount.objects.clear
  FSpecHooked.objects.clear
  FSpecHookedChild.objects.clear
  FSpecNormalized.objects.clear
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
