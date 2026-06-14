module Quartz


  # An FAdapter owns where and how records physically live
  # INFO: an in-memory hash today, a SQL table tomorrow.
  #
  # ```
  # FManager( User ).new                                # default: FMemoryAdapter
  # FManager( User ).new( FMemoryAdapter( User ).new )  # explicit
  # ```
  #
  # `TInstance` is expected to be a `Quartz::AModel` subclass.
  abstract class FAdapter( TInstance )

    #--------------------------------------------------------------------------

    # Persists a record, assigning the next id if it has none yet. Returns the
    # record. Storing under an id that is already taken replaces the previous one.
    abstract def store( record : TInstance ) : TInstance

    # Every stored record, in insertion order.
    abstract def all : Array( TInstance )

    # Number of stored records.
    abstract def count : Int32

    # The record with the given id, or `nil`.
    abstract def find?( id : UInt64 ) : TInstance?

    # Oldest stored record, or `nil` when empty.
    abstract def first? : TInstance?

    # Most recently inserted record, or `nil` when empty.
    abstract def last? : TInstance?

    # Removes the record with the given id. Returns `false` if absent.
    abstract def delete( id : UInt64 ) : Bool

    # Removes every record and resets the id sequence.
    abstract def clear : Nil

    #--------------------------------------------------------------------------

  end


end
