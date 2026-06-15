require "./Quartz"
require "sqlite3"


module Quartz


  # Concrete SQLite `FAdapter`, storing each model field in its own real column.
  #
  # ```
  # require "QuartzSQLite"
  # adapter = Quartz::FSqliteAdapter( Post ).new( "posts.db" )
  # manager = Quartz::FManager( Post ).new( adapter )
  # manager.create( title: "Hi" )
  # ```
  #
  # `TInstance` is expected to be a concrete `Quartz::AModel` subclass.
  class FSqliteAdapter( TInstance ) < FAdapter( TInstance )

    #--------------------------------------------------------------------------

    # Opens (creating if absent) the SQLite database at `path` and ensures the
    # model's table exists. Pass `":memory:"` for an in-memory database.
    def initialize( path : String )
      @db = DB.open( "sqlite3://#{path}" )
      _ensure_table
    end

    # Wraps an already-open `DB::Database` (e.g. a shared connection).
    # Ensures the model's table exists.
    def initialize( @db : DB::Database )
      _ensure_table
    end

    # Closes the underlying database.
    def close : Nil
      @db.close
    end

    #--------------------------------------------------------------------------

    # Persists a record.
    #  - no id      -> INSERTed & assigned a new id
    # - existing id -> INSERT OR REPLACEd, preserving that id
    def store( record : TInstance ) : TInstance
      cols = TInstance._quartz_columns

      if ! record.persisted?
        if cols.empty?
          result = @db.exec( "INSERT INTO #{_table} DEFAULT VALUES" )
        else
          placeholders = Array.new( cols.size, "?" ).join( ", " )
          result = @db.exec(
            "INSERT INTO #{_table} (#{cols.join( ", " )}) VALUES (#{placeholders})",
            args: record._quartz_db_args
          )
        end
        record.id = result.last_insert_id.to_u64
      else
        all_cols = [ "id" ] + cols
        placeholders = Array.new( all_cols.size, "?" ).join( ", " )
        args = ( [ record.id.to_i64 ] of DB::Any ) + record._quartz_db_args
        @db.exec(
          "INSERT OR REPLACE INTO #{_table} (#{all_cols.join( ", " )}) VALUES (#{placeholders})",
          args: args
        )
      end

      record
    end

    def all : Array( TInstance )
      records = [] of TInstance
      @db.query( "SELECT #{_select_list} FROM #{_table} ORDER BY id" ) do |rs|
        rs.each { records << TInstance._quartz_from_rs( rs ) }
      end
      records
    end

    def count : Int32
      @db.scalar( "SELECT COUNT(*) FROM #{_table}" ).as( Int64 ).to_i32
    end

    # Returns the record with the given id, or `nil`.
    def find?( id : UInt64 ) : TInstance?
      _query_one( "SELECT #{_select_list} FROM #{_table} WHERE id = ?", id.to_i64 )
    end

    # Oldest stored record, or `nil` when empty.
    def first? : TInstance?
      _query_one( "SELECT #{_select_list} FROM #{_table} ORDER BY id ASC LIMIT 1" )
    end

    # Most recently inserted record, or `nil` when empty.
    def last? : TInstance?
      _query_one( "SELECT #{_select_list} FROM #{_table} ORDER BY id DESC LIMIT 1" )
    end

    # Removes the record with the given id. Returns `false` if absent.
    def delete( id : UInt64 ) : Bool
      result = @db.exec( "DELETE FROM #{_table} WHERE id = ?", id.to_i64 )
      result.rows_affected > 0
    end

    # Removes every record and resets the id sequence so ids restart at 1
    # (matching `FMemoryAdapter#clear`).
    def clear : Nil
      @db.exec( "DELETE FROM #{_table}" )
      @db.exec( "DELETE FROM sqlite_sequence WHERE name = ?", _table )
    end

    #--------------------------------------------------------------------------

    private def _table : String
      TInstance._quartz_table
    end

    # `"id"` plus the field columns; `"id"`-only for a field-less model.
    private def _select_list : String
      cols = TInstance._quartz_columns
      cols.empty? ? "id" : "id, #{cols.join( ", " )}"
    end

    # Creates the table if it does not exist: an autoincrement `id` primary key
    # plus one column per field (DDL from `_quartz_column_defs`).
    private def _ensure_table : Nil
      defs = TInstance._quartz_column_defs
      columns = "id INTEGER PRIMARY KEY AUTOINCREMENT"
      columns += ", #{defs.join( ", " )}" unless defs.empty?
      @db.exec( "CREATE TABLE IF NOT EXISTS #{_table} (#{columns})" )
    end

    # Runs a single-row query, returning the mapped record or `nil` when empty.
    private def _query_one( sql : String, *args ) : TInstance?
      record = nil
      @db.query( sql, args: args.to_a.map( &.as( DB::Any ) ) ) do |rs|
        record = TInstance._quartz_from_rs( rs ) if rs.move_next
      end
      record
    end

    #--------------------------------------------------------------------------

  end


end
