require "../SpecHelper"

describe Quartz::AModel do
  before_each { quartz_spec_reset }

  describe "generated #initialize" do
    it "accepts typed keyword arguments" do
      user = FSpecUser.new(name: "Léo", age: 24)
      user.name.should eq("Léo")
      user.age.should eq(24)
    end

    it "applies default field values" do
      FSpecUser.new(name: "Bob").age.should eq(18)
    end

    it "accepts unicode, emoji and empty strings" do
      FSpecUser.new(name: "").name.should eq("")
      FSpecUser.new(name: "我爱你中国 ❤️").name.should eq("我爱你中国 ❤️")
    end

    it "accepts negative numeric values" do
      FSpecUser.new(name: "Léo", age: -5).age.should eq(-5)
    end
  end

  describe "#persisted?" do
    it "is false before save and true after" do
      user = FSpecUser.new(name: "Léo")
      user.persisted?.should be_false
      user.save!
      user.persisted?.should be_true
    end
  end

  describe "#save" do
    it "assigns an id and stores the record" do
      user = FSpecUser.new(name: "Léo").save!
      user.id.should eq(1)
      FSpecUser.objects.find(1).should eq(user)
    end

    it "updates in place when saved twice" do
      user = FSpecUser.new(name: "Léo").save!
      user.age = 30
      user.save!
      FSpecUser.objects.count.should eq(1)
      FSpecUser.objects.find(user.id).age.should eq(30)
    end

    it "re-keys the record after a manual id reassignment" do
      user = FSpecUser.new(name: "Léo").save!
      user.id = 999_i64
      user.save!
      FSpecUser.objects.count.should eq(1)
      FSpecUser.objects.find?(999).should be(user)
      FSpecUser.objects.find?(1).should be_nil
    end
  end

  describe "#delete" do
    it "removes the record and reports absence" do
      user = FSpecUser.new(name: "Léo").save!
      user.delete.should be_true
      user.delete.should be_false
      FSpecUser.objects.count.should eq(0)
    end

    it "resets the id so the record is no longer persisted" do
      user = FSpecUser.new(name: "Léo").save!
      user.delete
      user.id.should eq(0)
      user.persisted?.should be_false
    end

    it "returns false for a never-saved record" do
      FSpecUser.new(name: "Léo").delete.should be_false
    end
  end

  describe "#to_h" do
    it "includes the id and every field" do
      user = FSpecUser.objects.create(name: "Léo", age: 24)
      user.to_h.should eq({"id" => 1_i64, "name" => "Léo", "age" => 24})
    end
  end

  describe "#[]" do
    it "reads fields by name" do
      user = FSpecUser.new(name: "Léo", age: 24)
      user["name"].should eq("Léo")
      user["age"].should eq(24)
      user["id"].should eq(0_i64)
    end

    it "raises UnknownField for an undeclared name" do
      expect_raises(Quartz::EUnknownField, /unknown field 'email' on FSpecUser/) do
        FSpecUser.new(name: "Léo")["email"]
      end
    end

    it "raises UnknownField for an empty name" do
      expect_raises(Quartz::EUnknownField) do
        FSpecUser.new(name: "Léo")[""]
      end
    end
  end

  describe "#== and #hash" do
    it "is true for identical id and fields" do
      FSpecUser.new(name: "Léo", age: 24).should eq(FSpecUser.new(name: "Léo", age: 24))
    end

    it "is false when a field differs" do
      FSpecUser.new(name: "Léo", age: 24).should_not eq(FSpecUser.new(name: "Léo", age: 23))
    end

    it "is false when ids differ" do
      a = FSpecUser.new(name: "Léo")
      b = FSpecUser.new(name: "Léo")
      a.save!
      a.should_not eq(b)
    end

    it "honors the ==/hash contract" do
      a = FSpecUser.new(name: "Léo", age: 24)
      b = FSpecUser.new(name: "Léo", age: 24)
      a.hash.should eq(b.hash)
      Set{a}.includes?(b).should be_true
      a.age = 23
      a.hash.should_not eq(b.hash)
    end
  end

  describe "#inspect and #to_s" do
    it "renders a full debug representation" do
      user = FSpecUser.objects.create(name: "Léo", age: 24)
      user.inspect.should eq(%(#<FSpecUser id=1 name="Léo" age=24>))
    end

    it "renders a concise display form" do
      user = FSpecUser.new(name: "Léo")
      user.to_s.should eq("FSpecUser#new")
      user.save!
      user.to_s.should eq("FSpecUser#1")
    end
  end

  describe ".fields" do
    it "lists declared field names in order" do
      FSpecUser.fields.should eq(["name", "age"])
      FSpecPost.fields.should eq(["title"])
    end
  end

  describe ".field_types" do
    it "maps field names to type names" do
      FSpecUser.field_types.should eq({"name" => "String", "age" => "Int32"})
    end
  end

  describe ".model_name" do
    it "returns the short class name" do
      FSpecUser.model_name.should eq("FSpecUser")
    end
  end

  describe ".objects" do
    it "is isolated per model class" do
      FSpecUser.objects.create(name: "Léo")
      FSpecPost.objects.count.should eq(0)
    end
  end

  describe "field-less models" do
    it "supports the whole generated API" do
      record = FSpecEmpty.new.save!
      FSpecEmpty.fields.should eq([] of String)
      record.to_h.should eq({"id" => 1_i64})
      record.inspect.should eq("#<FSpecEmpty id=1>")
      record.delete.should be_true
    end
  end

  describe "model inheritance" do
    it "merges ancestor fields into the subclass, root-most first" do
      FSpecAdmin.fields.should eq(["name", "age", "role"])
      admin = FSpecAdmin.new(name: "Léo", age: 24, role: "root")
      admin.role.should eq("root")
      admin.to_h.should eq({"id" => 0_i64, "name" => "Léo", "age" => 24, "role" => "root"})
    end

    it "supports abstract bases" do
      FSpecArticle.fields.should eq(["created_at", "title"])
      FSpecArticle.new(title: "Hello").created_at.should eq("now")
    end

    it "keeps managers isolated between parent and child" do
      FSpecAdmin.objects.create(name: "Léo", role: "root")
      FSpecUser.objects.count.should eq(0)
      FSpecAdmin.objects.count.should eq(1)
    end
  end

  describe "field macro compile-time guards" do
    it "rejects a duplicate field" do
      result = quartz_compile(<<-CR)
        class Dup < Quartz::AModel
          field name : String
          field name : String
        end
        CR
      result[:success].should be_false
      result[:output].should contain("duplicate field `name`")
    end

    it "rejects a field shadowing an ancestor field" do
      result = quartz_compile(<<-CR)
        class Parent < Quartz::AModel
          field name : String
        end

        class Child < Parent
          field name : String
        end
        CR
      result[:success].should be_false
      result[:output].should contain("already declared on ancestor Parent")
    end

    it "rejects the reserved name id" do
      result = quartz_compile(<<-CR)
        class Bad < Quartz::AModel
          field id : UInt64
        end
        CR
      result[:success].should be_false
      result[:output].should contain("`id` is reserved")
    end

    it "rejects a non-type-declaration argument" do
      result = quartz_compile(<<-CR)
        class Bad < Quartz::AModel
          field 42
        end
        CR
      result[:success].should be_false
      result[:output].should contain("expects a type declaration")
    end
  end
end
