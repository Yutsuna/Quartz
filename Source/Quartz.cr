require "./Quartz/**"

# class User < Quartz::AModel
#   field name : String
#   field age : Int32
# end

# User.objects.create( name: "Léo", age: 24 )
# User.objects.create( name: "Jacques", age: 53 )
# User.objects.create( name: "Xavier", age: 16 )

# adults = User.objects
#   .filter { |u| u.age >= 18 }
#   .exclude { |u| u.name == "admin" }
#   .order_by { |u| u.age  }
#   .limit ( 10 )

# adults.to_a
