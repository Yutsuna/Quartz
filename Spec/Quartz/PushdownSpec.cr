require "../SpecHelper"

def seed_users : Nil
  FSpecUser.objects.create( name: "Léo", age: 24 )
  FSpecUser.objects.create( name: "Bob", age: 15 )
  FSpecUser.objects.create( name: "admin", age: 40 )
end

# Type-safe, push-down `AModel.where` / `.exclude` over the default in-memory
# adapter. The SQL backend's parity with these results is asserted in
# `SqliteAdapterSpec`.
describe "push-down queries" do
  before_each { quartz_spec_reset }

  describe "AModel.where (keyword form)" do
    it "matches a raw value with equality" do
      seed_users
      FSpecUser.where( name: "Léo" ).map( &.name ).should eq( ["Léo"] )
    end

    it "AND-composes several keywords" do
      seed_users
      FSpecUser.where( name: "Léo", age: 24 ).map( &.name ).should eq( ["Léo"] )
      FSpecUser.where( name: "Léo", age: 99 ).to_a.should be_empty
    end

    it "treats an endless Range as >=" do
      seed_users
      FSpecUser.where( age: 18.. ).map( &.name ).should eq( ["Léo", "admin"] )
    end

    it "treats a beginless exclusive Range as <" do
      seed_users
      FSpecUser.where( age: ...18 ).map( &.name ).should eq( ["Bob"] )
    end

    it "treats a closed Range as BETWEEN" do
      seed_users
      FSpecUser.where( age: 18..30 ).map( &.name ).should eq( ["Léo"] )
    end

    it "supports explicit operator hashes" do
      seed_users
      FSpecUser.where( age: {gt: 18} ).map( &.name ).should eq( ["Léo", "admin"] )
      FSpecUser.where( age: {lte: 24} ).map( &.name ).should eq( ["Léo", "Bob"] )
      FSpecUser.where( age: {ne: 24} ).map( &.name ).should eq( ["Bob", "admin"] )
    end

    it "treats an Array as IN" do
      seed_users
      FSpecUser.where( name: ["Léo", "Bob"] ).map( &.name ).should eq( ["Léo", "Bob"] )
    end

    it "is lazy and re-evaluable" do
      query = FSpecUser.where( age: 18.. )
      FSpecUser.objects.create( name: "Léo", age: 24 )
      query.count.should eq( 1 )
      FSpecUser.objects.create( name: "Zoé", age: 30 )
      query.count.should eq( 2 )
    end
  end

  describe "AModel.exclude (keyword form)" do
    it "negates an equality" do
      seed_users
      FSpecUser.exclude( name: "admin" ).map( &.name ).should eq( ["Léo", "Bob"] )
    end

    it "negates a Range" do
      seed_users
      FSpecUser.exclude( age: ...18 ).map( &.name ).should eq( ["Léo", "admin"] )
    end

    it "negates an IN list" do
      seed_users
      FSpecUser.exclude( name: ["Léo", "Bob"] ).map( &.name ).should eq( ["admin"] )
    end
  end

  describe "chaining" do
    it "orders by a column, ascending and descending" do
      seed_users
      FSpecUser.where( age: 0.. ).order_by( :age ).map( &.age ).should eq( [15, 24, 40] )
      FSpecUser.where( age: 0.. ).order_by( :age, reverse: true ).map( &.age ).should eq( [40, 24, 15] )
    end

    it "paginates with limit and offset" do
      seed_users
      FSpecUser.where( age: 0.. ).order_by( :age ).limit( 2 ).map( &.age ).should eq( [15, 24] )
      FSpecUser.where( age: 0.. ).order_by( :age ).offset( 1 ).map( &.age ).should eq( [24, 40] )
    end

    it "falls back to in-memory block transforms after a push-down where" do
      seed_users
      FSpecUser.where( age: 18.. ).filter { |u| u.name.starts_with?( "L" ) }.map( &.name ).should eq( ["Léo"] )
    end
  end

  describe "block form (backward compatible)" do
    it "where returns an eager Array" do
      seed_users
      FSpecUser.where { |u| u.age > 20 }.map( &.name ).should eq( ["Léo", "admin"] )
    end

    it "exclude returns a lazy FQuerySet" do
      seed_users
      FSpecUser.exclude { |u| u.name == "admin" }.map( &.name ).should eq( ["Léo", "Bob"] )
    end
  end

  describe "compile-time type safety" do
    it "rejects an unknown field name" do
      result = quartz_compile( <<-CR )
        class CTUser < Quartz::AModel
          field age : Int32 = 0
        end
        CTUser.where( agee: 1 )
        CR
      result[:success].should be_false
      result[:output].should contain( "_q_agee" )
    end

    it "rejects a value of the wrong type" do
      result = quartz_compile( <<-CR )
        class CTUser < Quartz::AModel
          field age : Int32 = 0
        end
        CTUser.where( age: "adult" )
        CR
      result[:success].should be_false
    end

    it "rejects a Range over the wrong type" do
      result = quartz_compile( <<-CR )
        class CTUser < Quartz::AModel
          field age : Int32 = 0
        end
        CTUser.where( age: "a".. )
        CR
      result[:success].should be_false
    end

    it "accepts native-typed values" do
      result = quartz_compile( <<-CR )
        class CTUser < Quartz::AModel
          field name : String = ""
          field age  : Int32  = 0
        end
        CTUser.where( age: 18.., name: ["a", "b"] ).order_by( :age ).limit( 5 )
        CR
      result[:success].should be_true
    end
  end
end
