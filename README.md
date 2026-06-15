# Quartz

Quartz is a Crystal ORM built around three goals: a compact model DSL, REPL-safe
macros, and a storage layer that can be swapped without changing the model API.

## Documentation

- [Architecture](Doc/Architecture.md)

## Quick start

```crystal
require "./Source/Quartz"

class Author < Quartz::AModel
  field name : String
  has_many books : Book
end

class Book < Quartz::AModel
  field title : String = ""
  belongs_to author : Author

  validates title, presence: true
  before_save { self.title = title.strip }
  timestamps
end

author = Author.objects.create(name: "Léo")
book = Book.objects.create(title: "  Crystal in Practice  ", author_id: author.id)

puts book.inspect
puts book.author
puts author.books
puts Book.objects
  .filter { |item| item.author_id == author.id }
  .order_by { |item| item.title }
  .to_a
```

## Installation

```bash
git clone https://github.com/Yutsuna/Quartz.git
cd Quartz
shards install
```

Quartz targets Crystal `>= 1.20.2`.

## Build and test

We recommand you to use [**Krystal**](https://github.com/Yutsuna/Krystal) to build and test Quartz.<br>
Krystal is a crystal compiler wrapper for big projects, really faster than `crystal build`.

```bash
krystal
krystal --force
krystal --release
krystal --spec
```

## Project layout

```text
Source/
  Quartz.cr
  Quartz/
    Models/
    Query/
    Adapters/
    Errors/
Spec/
Doc/
```

## Contributing

1. Fork the repository.
2. Create a feature branch.
3. Commit your changes.
4. Push the branch.
5. Open a pull request.
