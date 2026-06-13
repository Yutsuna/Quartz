require "./SpecHelper"
require "./Quartz/ModelSpec"
require "./Quartz/ManagerSpec"
require "./Quartz/RelationsSpec"
require "./Quartz/ValidationsSpec"
require "./Quartz/ReflectionSpec"
require "./Quartz/ErrorsSpec"
require "./Quartz/ReplSpec"

describe Quartz do
  it "exposes the library version" do
    Quartz::VERSION.should eq("0.1.0")
  end
end
