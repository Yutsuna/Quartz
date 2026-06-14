require "../SpecHelper"

describe "JSON serialization" do
  before_each { quartz_spec_reset }

  describe "#to_json" do
    it "emits id first, then every field in declared order" do
      record = FSpecUser.objects.create(name: "Léo", age: 24)
      record.to_json.should eq(%({"id":1,"name":"Léo","age":24}))
    end

    it "emits a nil field as null" do
      record = FSpecStamped.new(title: "x")
      record.to_json.should eq(%({"id":0,"title":"x","created_at":null,"updated_at":null}))
    end
  end

  describe ".from_json" do
    it "builds a transient record (id 0) from JSON" do
      record = FSpecUser.from_json(%({"name":"Bob","age":30}))
      record.id.should eq(0)
      record.name.should eq("Bob")
      record.age.should eq(30)
    end

    it "applies the field default for an absent key" do
      record = FSpecUser.from_json(%({"name":"Bob"}))
      record.age.should eq(18)
    end

    it "raises EDeserialization for an absent required field" do
      expect_raises(Quartz::EDeserialization, "name") do
        FSpecUser.from_json(%({"age":1}))
      end
    end

    it "reads an id when present" do
      record = FSpecUser.from_json(%({"id":7,"name":"Bob","age":30}))
      record.id.should eq(7)
    end
  end

  describe "round-trip" do
    it "preserves id and every field" do
      record = FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.from_json(record.to_json).should eq(record)
    end

    it "round-trips a model with Time? fields (RFC 3339, second precision)" do
      record = FSpecStamped.objects.create(title: "Hi")
      parsed = FSpecStamped.from_json(record.to_json)

      parsed.id.should eq(record.id)
      parsed.title.should eq(record.title)
      parsed.created_at.not_nil!.to_unix.should eq(record.created_at.not_nil!.to_unix)
      parsed.updated_at.not_nil!.to_unix.should eq(record.updated_at.not_nil!.to_unix)
    end

    it "leaves nilable timestamps nil when absent" do
      record = FSpecStamped.from_json(%({"title":"x"}))
      record.created_at.should be_nil
      record.updated_at.should be_nil
    end
  end
end
