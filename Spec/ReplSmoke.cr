# REPL smoke scenario, executed by `Spec/Quartz/ReplSpec.cr` through
# `crystal i` to guard the project's headline requirement: everything must
# work in the interpreter. Keep output assertions in sync with ReplSpec.
require "../Source/Quartz"

class ReplUser < Quartz::AModel
  field name : String
  field age : Int32 = 18
end

user = ReplUser.objects.create(name: "Léo", age: 24)
puts user.inspect
puts ReplUser.objects.create(name: "Bob").age
puts ReplUser.objects.find(2).inspect
puts ReplUser.objects.find_by?(name: "Bob").inspect
puts ReplUser.objects.where { |u| u.age > 20 }.size
puts user.to_h
puts ReplUser.fields
puts Quartz.model_names
