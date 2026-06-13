# Quartz

ORM REPL Interactive-friendly written in Crystal

```crystal
Crystal interpreter 1.20.2 (2026-05-16).
EXPERIMENTAL SOFTWARE: if you find a bug, please consider opening an issue in
https://github.com/crystal-lang/crystal/issues/new/
icr:1> require "./Source/**"
 => nil
icr:2> class User < Quartz::AModel
icr:3>   field name : String
icr:4>   field age : Int32
icr:5> end
 => nil
icr:6> User.objects.create(name: "Léo", age: 24)
 => #<User id=1 name="Léo" age=24>
icr:7> User.objects.create(name: "Jacques", age: 53)
 => #<User id=2 name="Jacques" age=53>
icr:8> User.objects.create(name: "Xavier", age: 16)
 => #<User id=3 name="Xavier" age=16>
icr:9>  adults = User.objects
icr:10>   .filter { |u| u.age >= 18 }
icr:11>   .exclude { |u| u.name == "admin" }
icr:12>   .order_by { |u| u.age }
icr:13>   .limit(10)
 => #<Quartz::QuerySet(User):0x7ff624a577e0 @source=#<Proc(Array(User)):0x7ff624a54280:closure>>
icr:14> adults.to_a
 => [#<User id=1 name="Léo" age=24>, #<User id=2 name="Jacques" age=53>]
icr:15>
```

## Installation

TODO: Write installation instructions here

## Usage

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/quartz/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [your-name-here](https://github.com/your-github-user) - creator and maintainer
