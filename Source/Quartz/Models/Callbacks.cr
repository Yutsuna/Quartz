require "./Model"


module Quartz


  # Lifecycle callback DSL for `AModel`.
  #
  # ```
  # class User < Quartz::AModel
  #   field name : String = ""
  #   field slug : String = ""
  #
  #   before_save   { self.slug = name.downcase }   # every persist
  #   before_create { self.name = name.strip }      # first persist only
  #   after_create  { puts "created ##{id}" }
  # end
  # ```
  #
  # save / create : before_save   -> (before_create if new) → store
  #                               -> (after_create if new) → after_save
  # delete        : before_delete -> delete → after_delete (only if removed)
  #
  # Each block runs in instance context (the record's fields and methods are in scope)
  abstract class AModel

    # Runs before every persist (create or update).
    macro before_save( &block )
      def _quartz_before_save : Nil
        previous_def
        {{block.body}}
      end
    end

    # Runs after every persist (create or update).
    macro after_save( &block )
      def _quartz_after_save : Nil
        previous_def
        {{block.body}}
      end
    end

    # Runs before the first persist of a record (when it has no id yet).
    macro before_create( &block )
      def _quartz_before_create : Nil
        previous_def
        {{block.body}}
      end
    end

    # Runs after the first persist of a record (id now assigned).
    macro after_create( &block )
      def _quartz_after_create : Nil
        previous_def
        {{block.body}}
      end
    end

    # Runs before a record is deleted.
    macro before_delete( &block )
      def _quartz_before_delete : Nil
        previous_def
        {{block.body}}
      end
    end

    # Runs after a record is actually removed (skipped when nothing was deleted).
    macro after_delete( &block )
      def _quartz_after_delete : Nil
        previous_def
        {{block.body}}
      end
    end

  end


end
