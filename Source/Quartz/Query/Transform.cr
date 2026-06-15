module Quartz


  class FQuerySet( TInstance )

    # Transform: each returns a new, lazily-composed QuerySet.

    # Keeps only the records for which `block` is truthy.
    def filter( & block : TInstance -> Bool ) : FQuerySet( TInstance )
      src = @source
      FQuerySet( TInstance ).new( -> { src.call.select { |record| block.call( record ) } } )
    end

    # Keeps only the records for which `block` is falsey.
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

    # Keeps at most the first `n` records. Pushes down to the spec when the set
    # is spec-backed (`FManager#where`), otherwise composes in memory.
    def limit( n : Int32 ) : FQuerySet( TInstance )
      if s = @spec
        next_spec = s._copy
        next_spec.limit = n
        return FQuerySet( TInstance ).new( next_spec, fetch! )
      end
      src = @source
      FQuerySet( TInstance ).new( -> { src.call.first( n ) } )
    end

    # Skips the first `n` records. Pushes down to the spec when the set is
    # spec-backed, otherwise composes in memory.
    def offset( n : Int32 ) : FQuerySet( TInstance )
      if s = @spec
        next_spec = s._copy
        next_spec.offset = n
        return FQuerySet( TInstance ).new( next_spec, fetch! )
      end
      src = @source
      FQuerySet( TInstance ).new( -> { src.call.skip( n ) } )
    end

    # Orders a spec-backed set by `column` (push-down `ORDER BY`), ascending by
    # default. The column is validated by the adapter's typed sorter.
    def order_by( column : Symbol, reverse : Bool = false ) : FQuerySet( TInstance )
      s = @spec.not_nil!
      next_spec = s._copy
      next_spec.order_column = column.to_s
      next_spec.order_reverse = reverse
      FQuerySet( TInstance ).new( next_spec, fetch! )
    end

  end


end
