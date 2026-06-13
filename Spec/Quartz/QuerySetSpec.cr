require "../SpecHelper"

describe Quartz::QuerySet do
  before_each { quartz_spec_reset }

  describe "laziness" do
    it "runs nothing until a terminal method is called" do
      query = FSpecUser.objects.filter { |u| u.age >= 18 }
      FSpecUser.objects.create(name: "Léo", age: 24)
      query.to_a.map(&.name).should eq(["Léo"])
    end

    it "re-evaluates on every terminal call" do
      query = FSpecUser.objects.filter { |u| u.age >= 18 }
      FSpecUser.objects.create(name: "Léo", age: 24)
      query.count.should eq(1)
      FSpecUser.objects.create(name: "Zoé", age: 30)
      query.count.should eq(2)
    end
  end

  describe "#filter / #exclude" do
    it "composes filters with logical AND" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.create(name: "Bob", age: 17)
      FSpecUser.objects.create(name: "Zoé", age: 30)
      result = FSpecUser.objects
        .filter { |u| u.age >= 18 }
        .filter { |u| u.name.starts_with?("Z") }
      result.map(&.name).should eq(["Zoé"])
    end

    it "excludes matching records" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.create(name: "admin", age: 99)
      FSpecUser.objects.exclude { |u| u.name == "admin" }.map(&.name).should eq(["Léo"])
    end

    it "combines filter and exclude" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.create(name: "admin", age: 40)
      FSpecUser.objects.create(name: "Bob", age: 17)
      result = FSpecUser.objects
        .filter { |u| u.age >= 18 }
        .exclude { |u| u.name == "admin" }
      result.map(&.name).should eq(["Léo"])
    end
  end

  describe "#order_by" do
    it "sorts ascending by the returned key" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.create(name: "Bob", age: 17)
      FSpecUser.objects.create(name: "Zoé", age: 30)
      FSpecUser.objects.order_by { |u| u.age }.map(&.age).should eq([17, 24, 30])
    end

    it "sorts descending with reverse: true" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.create(name: "Bob", age: 17)
      FSpecUser.objects.create(name: "Zoé", age: 30)
      FSpecUser.objects.order_by(reverse: true) { |u| u.age }.map(&.age).should eq([30, 24, 17])
    end
  end

  describe "#limit / #offset" do
    it "limits the number of records" do
      3.times { |i| FSpecUser.objects.create(name: "u#{i}", age: i) }
      FSpecUser.objects.order_by { |u| u.age }.limit(2).map(&.age).should eq([0, 1])
    end

    it "skips records with offset" do
      3.times { |i| FSpecUser.objects.create(name: "u#{i}", age: i) }
      FSpecUser.objects.order_by { |u| u.age }.offset(1).map(&.age).should eq([1, 2])
    end

    it "composes filter, order, offset and limit" do
      5.times { |i| FSpecUser.objects.create(name: "u#{i}", age: i) }
      result = FSpecUser.objects
        .filter { |u| u.age >= 1 }
        .order_by(reverse: true) { |u| u.age }
        .offset(1)
        .limit(2)
      result.map(&.age).should eq([3, 2])
    end
  end

  describe "terminals" do
    it "reports count, empty?, any? and exists?" do
      FSpecUser.objects.filter { |u| u.age > 0 }.empty?.should be_true
      FSpecUser.objects.filter { |u| u.age > 0 }.any?.should be_false
      FSpecUser.objects.create(name: "Léo", age: 24)
      query = FSpecUser.objects.filter { |u| u.age > 0 }
      query.count.should eq(1)
      query.empty?.should be_false
      query.any?.should be_true
      query.exists?.should be_true
    end

    it "returns first?/last?, or nil when empty" do
      FSpecUser.objects.order_by { |u| u.age }.first?.should be_nil
      FSpecUser.objects.order_by { |u| u.age }.last?.should be_nil
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.create(name: "Bob", age: 17)
      ordered = FSpecUser.objects.order_by { |u| u.age }
      ordered.first?.try(&.name).should eq("Bob")
      ordered.last?.try(&.name).should eq("Léo")
    end

    it "raises ERecordNotFound from bang first/last on an empty set" do
      expect_raises(Quartz::ERecordNotFound) { FSpecUser.objects.filter { |u| u.age > 0 }.first }
      expect_raises(Quartz::ERecordNotFound) { FSpecUser.objects.filter { |u| u.age > 0 }.last }
    end

    it "returns existing first/last" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.order_by { |u| u.age }.first.name.should eq("Léo")
    end
  end

  describe "Enumerable mixin" do
    it "supports map/select over results" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.create(name: "Bob", age: 17)
      query = FSpecUser.objects.filter { |u| u.age >= 18 }
      query.map(&.name).should eq(["Léo"])
      query.select { |u| u.age > 100 }.should be_empty
    end

    it "yields the same live reference the manager holds" do
      user = FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.query.first?.should be(user)
    end
  end

  describe "manager entry points" do
    it "exposes query/filter/exclude/order_by" do
      FSpecUser.objects.create(name: "Léo", age: 24)
      FSpecUser.objects.query.count.should eq(1)
      FSpecUser.objects.filter { |u| u.age >= 18 }.count.should eq(1)
      FSpecUser.objects.exclude { |u| u.age >= 18 }.count.should eq(0)
      FSpecUser.objects.order_by { |u| u.age }.count.should eq(1)
    end
  end
end
