require "./SpecHelper"
require "./Quartz/**"

describe Quartz do
  it "exposes the library version" do
    Quartz::VERSION.should eq("0.1.0")
  end
end
