require "../SpecHelper"

describe Quartz::FManager do
  before_each { quartz_spec_reset }

  describe "#create" do
    it "instantiates, persists and assigns sequential ids" do
      a = FSpecUser.objects.create(name: "Léo", age: 24)
      b = FSpecUser.objects.create(name: "Bob")
      a.id.should eq(1)
      b.id.should eq(2)
      FSpecUser.objects.count.should eq(2)
    end
  end

  describe "#store" do
    it "keeps the id sequence ahead of explicitly-assigned ids" do
      user = FSpecUser.new(name: "Léo")
      user.id = 5_i64
      FSpecUser.objects.store(user)
      FSpecUser.objects.create(name: "Bob").id.should eq(6)
      FSpecUser.objects.count.should eq(2)
    end

    it "replaces the record when an explicit id is already taken" do
      FSpecUser.objects.create(name: "Léo")
      replacement = FSpecUser.new(name: "Zoé")
      replacement.id = 1_i64
      FSpecUser.objects.store(replacement)
      FSpecUser.objects.count.should eq(1)
      FSpecUser.objects.find(1).name.should eq("Zoé")
      FSpecUser.objects.create(name: "Bob").id.should eq(2)
    end

    it "fails atomically on UInt64 overflow" do
      user = FSpecUser.new(name: "Léo")
      user.id = UInt64::MAX
      expect_raises(OverflowError) do
        FSpecUser.objects.store(user)
      end
      FSpecUser.objects.count.should eq(0)
      FSpecUser.objects.create(name: "Bob").id.should eq(1)
    end
  end

  describe "#all" do
    it "returns every record in insertion order" do
      FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.create(name: "Bob")
      FSpecUser.objects.all.map(&.name).should eq(["Léo", "Bob"])
    end

    it "is empty for a fresh manager" do
      FSpecUser.objects.all.should be_empty
    end
  end

  describe "#find" do
    it "returns the record with the given id" do
      user = FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.find(user.id).should eq(user)
    end

    it "raises RecordNotFound for a missing id" do
      expect_raises(Quartz::ERecordNotFound, /FSpecUser with id=42 not found/) do
        FSpecUser.objects.find(42)
      end
    end
  end

  describe "#find?" do
    it "returns nil for a missing id" do
      FSpecUser.objects.find?(42).should be_nil
    end
  end

  describe "#find_by? / #find_by" do
    it "returns the first record matching every argument" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      bob = FSpecUser.objects.create(name: "Bob", age: 24)
      FSpecUser.objects.find_by?(name: "Bob", age: 24).should eq(bob)
      FSpecUser.objects.find_by(name: "Bob", age: 24).should eq(bob)
    end

    it "returns nil when only part of the arguments match" do
      FSpecUser.objects.create(name: "Bob", age: 24)
      FSpecUser.objects.find_by?(name: "Bob", age: 99).should be_nil
    end

    it "returns nil when nothing matches" do
      FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.find_by?(name: "Zoé").should be_nil
    end

    it "raises RecordNotFound from the bang-style variant" do
      expect_raises(Quartz::ERecordNotFound, /FSpecUser matching/) do
        FSpecUser.objects.find_by(name: "Zoé")
      end
    end

    it "returns the first record when called without arguments" do
      first = FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.create(name: "Bob")
      FSpecUser.objects.find_by?.should eq(first)
    end

    it "validates field names against the schema, even on an empty store" do
      expect_raises(Quartz::EUnknownField, /unknown field 'email' on FSpecUser/) do
        FSpecUser.objects.find_by?(email: "leo@example.com")
      end
    end

    it "allows querying by id" do
      user = FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.find_by?(id: user.id).should eq(user)
    end
  end

  describe "#where" do
    it "filters records with a typed block" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.create(name: "Bob", age: 17)
      adults = FSpecUser.objects.where { |user| user.age >= 18 }
      adults.map(&.name).should eq(["Léo"])
    end

    it "returns an empty array when nothing matches" do
      FSpecUser.objects.where { |user| user.age > 100 }.should be_empty
    end
  end

  describe "#first? / #last?" do
    it "returns boundary records, or nil when empty" do
      FSpecUser.objects.first?.should be_nil
      FSpecUser.objects.last?.should be_nil
      FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.create(name: "Bob")
      FSpecUser.objects.first?.try(&.name).should eq("Léo")
      FSpecUser.objects.last?.try(&.name).should eq("Bob")
    end
  end

  describe "#delete" do
    it "removes the record and returns whether it existed" do
      user = FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.delete(user.id).should be_true
      FSpecUser.objects.delete(user.id).should be_false
    end

    it "returns false for the unsaved sentinel ids" do
      FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.delete(0).should be_false
    end
  end

  describe "#clear" do
    it "removes every record and resets the id sequence" do
      FSpecUser.objects.create(name: "Léo")
      FSpecUser.objects.clear
      FSpecUser.objects.count.should eq(0)
      FSpecUser.objects.create(name: "Bob").id.should eq(1)
    end
  end

  describe "concurrent access" do
    it "stays consistent when creating from many fibers" do
      done = Channel(Nil).new
      10.times do |i|
        spawn do
          FSpecUser.objects.create(name: "user-#{i}")
          done.send(nil)
        end
      end
      10.times { done.receive }
      FSpecUser.objects.count.should eq(10)
      FSpecUser.objects.all.map(&.id).sort!.should eq((1_i64..10_i64).to_a)
    end
  end
end
