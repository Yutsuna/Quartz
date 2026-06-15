require "../SpecHelper"
require "../../Source/QuartzSQLite"

def with_sqlite_adapter( klass : T.class, &block : Quartz::FSqliteAdapter( T ) -> _ ) forall T
  path = File.tempfile( "quartz_sqlite_spec", ".db" ).path
  adapter = Quartz::FSqliteAdapter( T ).new( path )
  begin
    block.call( adapter )
  ensure
    adapter.close
    File.delete( path ) if File.exists?( path )
  end
end

# Builds a spec via the model's typed helpers, mirroring `AModel.where`, then
# evaluates it against both the SQLite and in-memory adapters and asserts
# identical results (push-down ↔ in-memory parity).
def assert_parity( adapter : Quartz::FSqliteAdapter( FSpecUser ), &build : Quartz::FQuerySpec( FSpecUser ) -> _ ) : Nil
  sql_mgr = Quartz::FManager( FSpecUser ).new( adapter )
  mem_mgr = Quartz::FManager( FSpecUser ).new

  [sql_mgr, mem_mgr].each do |mgr|
    mgr.create( name: "Léo", age: 24 )
    mgr.create( name: "Bob", age: 15 )
    mgr.create( name: "admin", age: 40 )
  end

  sql_spec = Quartz::FQuerySpec( FSpecUser ).new
  mem_spec = Quartz::FQuerySpec( FSpecUser ).new
  build.call( sql_spec )
  build.call( mem_spec )

  sql_mgr.fetch( sql_spec ).map( &.name ).should eq( mem_mgr.fetch( mem_spec ).map( &.name ) )
  sql_mgr.fetch_count( sql_spec ).should eq( mem_mgr.fetch_count( mem_spec ) )
end

describe Quartz::FSqliteAdapter do
  describe "#store" do
    it "assigns sequential ids to unpersisted records" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        a = adapter.store( FSpecUser.new( name: "Léo" ) )
        b = adapter.store( FSpecUser.new( name: "Bob" ) )
        a.id.should eq( 1 )
        b.id.should eq( 2 )
      end
    end

    it "advances the sequence past an explicit id" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        seeded = FSpecUser.new( name: "Léo" )
        seeded.id = 5_i64
        adapter.store( seeded )
        adapter.store( FSpecUser.new( name: "Bob" ) ).id.should eq( 6 )
      end
    end

    it "replaces the record stored under a taken id" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        adapter.store( FSpecUser.new( name: "Léo" ) )
        replacement = FSpecUser.new( name: "Zoé" )
        replacement.id = 1_i64
        adapter.store( replacement )
        adapter.count.should eq( 1 )
        adapter.find?( 1_u64 ).try( &.name ).should eq( "Zoé" )
      end
    end
  end

  describe "#all / #count / #find?" do
    it "returns records in insertion order" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        adapter.store( FSpecUser.new( name: "Léo" ) )
        adapter.store( FSpecUser.new( name: "Bob" ) )
        adapter.all.map( &.name ).should eq( ["Léo", "Bob"] )
        adapter.count.should eq( 2 )
      end
    end

    it "returns nil for a missing id" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        adapter.find?( 42_u64 ).should be_nil
      end
    end
  end

  describe "#first? / #last?" do
    it "returns boundary records, or nil when empty" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        adapter.first?.should be_nil
        adapter.last?.should be_nil
        adapter.store( FSpecUser.new( name: "Léo" ) )
        adapter.store( FSpecUser.new( name: "Bob" ) )
        adapter.first?.try( &.name ).should eq( "Léo" )
        adapter.last?.try( &.name ).should eq( "Bob" )
      end
    end
  end

  describe "#delete" do
    it "removes the record and reports whether it existed" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        user = adapter.store( FSpecUser.new( name: "Léo" ) )
        adapter.delete( user.id ).should be_true
        adapter.delete( user.id ).should be_false
      end
    end
  end

  describe "#clear" do
    it "removes every record and resets the id sequence" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        adapter.store( FSpecUser.new( name: "Léo" ) )
        adapter.clear
        adapter.count.should eq( 0 )
        adapter.store( FSpecUser.new( name: "Bob" ) ).id.should eq( 1 )
      end
    end
  end

  describe "real per-field columns" do
    it "round-trips scalar field values through their own columns" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        adapter.store( FSpecUser.new( name: "Léo", age: 24 ) )
        fetched = adapter.find?( 1_u64 ).not_nil!
        fetched.name.should eq( "Léo" )
        fetched.age.should eq( 24 )
      end
    end

    it "round-trips a Time column to second precision" do
      with_sqlite_adapter( FSpecStamped ) do |adapter|
        record = FSpecStamped.new( title: "x" )
        record.created_at = Time.utc( 2026, 6, 15, 12, 0, 0 )
        adapter.store( record )
        fetched = adapter.find?( 1_u64 ).not_nil!
        fetched.created_at.not_nil!.to_unix.should eq( record.created_at.not_nil!.to_unix )
      end
    end

    it "round-trips a nil nilable column" do
      with_sqlite_adapter( FSpecStamped ) do |adapter|
        adapter.store( FSpecStamped.new( title: "x" ) )
        fetched = adapter.find?( 1_u64 ).not_nil!
        fetched.created_at.should be_nil
        fetched.updated_at.should be_nil
      end
    end

    it "round-trips a complex field through a JSON-text column" do
      with_sqlite_adapter( FSpecHooked ) do |adapter|
        record = FSpecHooked.new( name: "n", trace: ["a", "b"] )
        adapter.store( record )
        fetched = adapter.find?( 1_u64 ).not_nil!
        fetched.trace.should eq( ["a", "b"] )
      end
    end

    it "handles a field-less model" do
      with_sqlite_adapter( FSpecEmpty ) do |adapter|
        a = adapter.store( FSpecEmpty.new )
        b = adapter.store( FSpecEmpty.new )
        a.id.should eq( 1 )
        b.id.should eq( 2 )
        adapter.count.should eq( 2 )
        adapter.find?( 1_u64 ).not_nil!.id.should eq( 1 )
      end
    end
  end

  describe "FManager integration" do
    it "drives create / find_by? / where end-to-end over SQLite" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        manager = Quartz::FManager( FSpecUser ).new( adapter )
        manager.create( name: "Léo", age: 30 )
        manager.create( name: "Bob", age: 18 )
        manager.count.should eq( 2 )
        manager.find_by?( name: "Bob" ).try( &.age ).should eq( 18 )
        manager.where { |u| u.age >= 20 }.map( &.name ).should eq( ["Léo"] )
      end
    end
  end

  describe "push-down queries (parity with the in-memory adapter)" do
    it "matches an endless Range (>=)" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        assert_parity( adapter ) { |s| FSpecUser._q_age( s, 18.., false ) }
      end
    end

    it "matches a closed Range (BETWEEN)" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        assert_parity( adapter ) { |s| FSpecUser._q_age( s, 18..30, false ) }
      end
    end

    it "matches an IN list" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        assert_parity( adapter ) { |s| FSpecUser._q_name( s, ["Léo", "Bob"], false ) }
      end
    end

    it "matches an explicit operator hash" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        assert_parity( adapter ) { |s| FSpecUser._q_age( s, {gt: 18}, false ) }
      end
    end

    it "negates a condition (exclude)" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        assert_parity( adapter ) { |s| FSpecUser._q_age( s, ...18, true ) }
      end
    end

    it "orders, limits and offsets" do
      with_sqlite_adapter( FSpecUser ) do |adapter|
        assert_parity( adapter ) do |s|
          FSpecUser._q_age( s, 0.., false )
          s.order_column = "age"
          s.order_reverse = true
          s.limit = 2
          s.offset = 1
        end
      end
    end
  end
end
