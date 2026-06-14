require "../Source/Quartz"

class ReplUser < Quartz::AModel
  field name : String
  field age : Int32 = 18
end

class ReplAuthor < Quartz::AModel
  field name : String
  has_many books : ReplBook, foreign_key: author_id
end

class ReplBook < Quartz::AModel
  field title : String
  belongs_to author : ReplAuthor
end

class ReplAccount < Quartz::AModel
  field email : String = ""
  validates email, presence: true
end

class ReplHooked < Quartz::AModel
  field name : String = ""
  before_save { self.name = name.upcase }
end

class ReplStamped < Quartz::AModel
  field title : String = ""
  timestamps
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

author = ReplAuthor.objects.create(name: "Léo")
book = ReplBook.objects.create(title: "Crystal", author_id: author.id)
puts book.author.inspect
puts author.books.size

puts ReplAccount.new(email: "").valid?
puts ReplAccount.new(email: "x@y.z").errors.empty?

ReplUser.objects.create(name: "Max", age: 40)
puts ReplUser.objects.filter { |u| u.age > 18 }.order_by { |u| u.age }.count

puts ReplHooked.objects.create(name: "bob").name

puts ReplStamped.objects.create(title: "x").created_at.class
