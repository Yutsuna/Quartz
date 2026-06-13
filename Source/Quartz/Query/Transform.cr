module Quartz


  class FQuerySet( TInstance )

    # Transform: each returns a new, lazily-composed QuerySet.

    # Keeps only the records for which `block` is truthy.
    def filter( & block : TInstance -> Bool ) : FQuerySet( TInstance )
      src = @source
      FQuerySet( TInstance ).new( -> { src.call.select { |record| block.call( record ) } } )
    end

    # Keeps only the records for which `block` is falsey
    def exclude( & block : TInstance -> Bool ) : FQuerySet( TInstance )
      src = @source
      FQuerySet( TInstance ).new( -> { src.call.reject { |record| block.call( record ) } } )
    end

    # Sorts records by the key `block` returns (`sort_by`), ascending by default.
    # Pass `reverse: true` for descending order.
    def order_by( reverse : Bool = false, & block : TInstance -> _ ) : FQuerySet( TInstance )
      src = @source
      FQuerySet( TInstance ).new( -> {
        sorted = src.call.sort_by { |record| block.call( record ) }
        reverse ? sorted.reverse! : sorted
      } )
    end

    # Keeps at most the first `n` records.
    def limit( n : Int32 ) : FQuerySet( TInstance )
      src = @source
      FQuerySet( TInstance ).new( -> { src.call.first( n ) } )
    end

    # Skips the first `n` records.
    def offset( n : Int32 ) : FQuerySet( TInstance )
      src = @source
      FQuerySet( TInstance ).new( -> { src.call.skip( n ) } )
    end

  end


end
