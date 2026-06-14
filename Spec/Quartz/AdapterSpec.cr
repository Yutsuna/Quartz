require "../SpecHelper"

class FSpecCountingAdapter( TInstance ) < Quartz::FAdapter( TInstance )
  getter stores = 0

  def initialize
    @inner = Quartz::FMemoryAdapter( TInstance ).new
  end

  def store( record : TInstance ) : TInstance
    @stores += 1
    @inner.store( record )
  end

  def all : Array( TInstance )
    @inner.all
  end

  def count : Int32
    @inner.count
  end

  def find?( id : UInt64 ) : TInstance?
    @inner.find?( id )
  end

  def first? : TInstance?
    @inner.first?
  end

  def last? : TInstance?
    @inner.last?
  end

  def delete( id : UInt64 ) : Bool
    @inner.delete( id )
  end

  def clear : Nil
    @inner.clear
  end
end

describe Quartz::FMemoryAdapter do
  describe "#store" do
    it "assigns sequential ids to unpersisted records" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      a = adapter.store(FSpecUser.new(name: "Léo"))
      b = adapter.store(FSpecUser.new(name: "Bob"))
      a.id.should eq(1)
      b.id.should eq(2)
    end

    it "is idempotent on an already-persisted record" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      user = adapter.store(FSpecUser.new(name: "Léo"))
      adapter.store(user)
      adapter.count.should eq(1)
      user.id.should eq(1)
    end

    it "advances the sequence past an explicit id" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      seeded = FSpecUser.new(name: "Léo")
      seeded.id = 5_i64
      adapter.store(seeded)
      adapter.store(FSpecUser.new(name: "Bob")).id.should eq(6)
    end

    it "replaces the record stored under a taken id" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      adapter.store(FSpecUser.new(name: "Léo"))
      replacement = FSpecUser.new(name: "Zoé")
      replacement.id = 1_i64
      adapter.store(replacement)
      adapter.count.should eq(1)
      adapter.find?(1_u64).try(&.name).should eq("Zoé")
    end

    it "drops a stale entry after a manual id reassignment" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      user = adapter.store(FSpecUser.new(name: "Léo"))
      user.id = 9_i64
      adapter.store(user)
      adapter.count.should eq(1)
      adapter.find?(1_u64).should be_nil
      adapter.find?(9_u64).should be(user)
    end
  end

  describe "#all / #count / #find?" do
    it "returns records in insertion order" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      adapter.store(FSpecUser.new(name: "Léo"))
      adapter.store(FSpecUser.new(name: "Bob"))
      adapter.all.map(&.name).should eq(["Léo", "Bob"])
      adapter.count.should eq(2)
    end

    it "returns nil for a missing id" do
      Quartz::FMemoryAdapter(FSpecUser).new.find?(42_u64).should be_nil
    end
  end

  describe "#first? / #last?" do
    it "returns boundary records, or nil when empty" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      adapter.first?.should be_nil
      adapter.last?.should be_nil
      adapter.store(FSpecUser.new(name: "Léo"))
      adapter.store(FSpecUser.new(name: "Bob"))
      adapter.first?.try(&.name).should eq("Léo")
      adapter.last?.try(&.name).should eq("Bob")
    end
  end

  describe "#delete" do
    it "removes the record and reports whether it existed" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      user = adapter.store(FSpecUser.new(name: "Léo"))
      adapter.delete(user.id).should be_true
      adapter.delete(user.id).should be_false
    end
  end

  describe "#clear" do
    it "removes every record and resets the id sequence" do
      adapter = Quartz::FMemoryAdapter(FSpecUser).new
      adapter.store(FSpecUser.new(name: "Léo"))
      adapter.clear
      adapter.count.should eq(0)
      adapter.store(FSpecUser.new(name: "Bob")).id.should eq(1)
    end
  end
end

describe Quartz::FManager do
  describe "pluggable adapter" do
    it "routes persistence through the injected adapter" do
      adapter = FSpecCountingAdapter(FSpecUser).new
      manager = Quartz::FManager(FSpecUser).new(adapter)
      manager.create(name: "Léo")
      manager.create(name: "Bob")
      adapter.stores.should eq(2)
      manager.count.should eq(2)
      manager.find_by?(name: "Bob").try(&.name).should eq("Bob")
    end

    it "isolates a manager over a fresh adapter from the model's own store" do
      before = FSpecUser.objects.count
      isolated = Quartz::FManager(FSpecUser).new(Quartz::FMemoryAdapter(FSpecUser).new)
      isolated.create(name: "Solo")
      isolated.count.should eq(1)
      FSpecUser.objects.count.should eq(before)
    end

    it "defaults to an in-memory adapter when none is given" do
      manager = Quartz::FManager(FSpecUser).new
      manager.create(name: "Léo").id.should eq(1)
    end
  end
end
