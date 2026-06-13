require "../SpecHelper"

describe "Quartz relationships" do
  before_each { quartz_spec_reset }

  describe "belongs_to" do
    it "registers a foreign-key field" do
      FSpecBook.fields.should contain("author_id")
      FSpecBook.field_types["author_id"].should eq("UInt64")
    end

    it "defaults the foreign key to 0 and includes it in to_h" do
      book = FSpecBook.objects.create(title: "Crystal")
      book.author_id.should eq(0)
      book.to_h.should eq({"id" => 1_u64, "title" => "Crystal", "author_id" => 0_u64})
    end

    it "is settable through the keyword constructor" do
      author = FSpecAuthor.objects.create(name: "Léo")
      book = FSpecBook.objects.create(title: "Crystal", author_id: author.id)
      book.author_id.should eq(author.id)
    end

    it "resolves the associated record through the getter" do
      author = FSpecAuthor.objects.create(name: "Léo")
      book = FSpecBook.objects.create(title: "Crystal", author_id: author.id)
      book.author.should eq(author)
    end

    it "returns nil when the foreign key is unset" do
      FSpecBook.objects.create(title: "Orphan").author.should be_nil
    end

    it "returns nil when the associated record was deleted" do
      author = FSpecAuthor.objects.create(name: "Léo")
      book = FSpecBook.objects.create(title: "Crystal", author_id: author.id)
      author.delete
      book.author.should be_nil
    end

    it "assigns the foreign key from a record through the setter" do
      author = FSpecAuthor.objects.create(name: "Léo")
      book = FSpecBook.objects.create(title: "Crystal")
      book.author = author
      book.author_id.should eq(author.id)
      book.save
      FSpecBook.objects.find(book.id).author.should eq(author)
    end
  end

  describe "has_many" do
    it "returns every related record" do
      author = FSpecAuthor.objects.create(name: "Léo")
      a = FSpecBook.objects.create(title: "Crystal", author_id: author.id)
      b = FSpecBook.objects.create(title: "Macros", author_id: author.id)
      author.books.should eq([a, b])
    end

    it "excludes records belonging to another owner" do
      author = FSpecAuthor.objects.create(name: "Léo")
      other = FSpecAuthor.objects.create(name: "Bob")
      mine = FSpecBook.objects.create(title: "Crystal", author_id: author.id)
      FSpecBook.objects.create(title: "Other", author_id: other.id)
      author.books.should eq([mine])
    end

    it "returns an empty array when there are no related records" do
      FSpecAuthor.objects.create(name: "Léo").books.should be_empty
    end

    it "honors a custom foreign_key" do
      library = FSpecLibrary.objects.create(name: "Central")
      shelved = FSpecShelvedBook.objects.create(title: "Crystal", shelf_id: library.id)
      FSpecShelvedBook.objects.create(title: "Elsewhere", shelf_id: 99_u64)
      library.books.should eq([shelved])
    end

    it "derives the foreign key from the owner class name by default" do
      # Single-word class names: `has_many books : Book` derives `author_id`,
      # which `belongs_to author : Author` provides — they meet by convention.
      result = quartz_compile(<<-CRYSTAL)
        class Author < Quartz::AModel
          field name : String
          has_many books : Book
        end

        class Book < Quartz::AModel
          field title : String
          belongs_to author : Author
        end

        author = Author.objects.create(name: "Léo")
        book = Book.objects.create(title: "Crystal", author_id: author.id)
        book.author
        author.books
        CRYSTAL
      result[:success].should be_true
    end
  end

  describe "inheritance" do
    it "inherits the foreign-key field and accessors on a subclass" do
      FSpecEbook.fields.should eq(["title", "author_id", "format"])
      author = FSpecAuthor.objects.create(name: "Léo")
      ebook = FSpecEbook.objects.create(title: "Crystal", author_id: author.id, format: "mobi")
      ebook.author.should eq(author)
      ebook.format.should eq("mobi")
    end
  end
end
