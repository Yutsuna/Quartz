require "../SpecHelper"

describe Quartz::AError do
  it "is the ancestor of every Quartz error" do
    Quartz::ERecordNotFound.new("User", 1_i64).should be_a(Quartz::AError)
    Quartz::EUnknownField.new("User", "email").should be_a(Quartz::AError)
  end

  it "builds descriptive messages" do
    Quartz::ERecordNotFound.new("User", 42_i64).message.should eq("User with id=42 not found")
    Quartz::ERecordNotFound.new("User", "{name: \"Zoé\"}").message.should eq(%(User matching {name: "Zoé"} not found))
    Quartz::EUnknownField.new("User", "email").message.should eq("unknown field 'email' on User")
  end
end
