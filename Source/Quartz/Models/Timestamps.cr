require "./Model"


module Quartz


  # Auto-timestamp DSL for `AModel`.
  #
  # Reopens `AModel` to add the `timestamps` macro, inherited by every subclass
  # like `field` and the callback macros.
  #
  # ```
  # class Post < Quartz::AModel
  #   field title : String = ""
  #   timestamps                      # adds created_at / updated_at : Time?
  # end
  #
  # p = Post.objects.create( title: "Hi" )
  # p.created_at        # => set on first persist (UTC)
  # p.updated_at        # => equal to created_at on create
  # p.save!             # => later: updated_at advances, created_at unchanged
  # Post.new.created_at # => nil (an unsaved record has no timestamps yet)
  # ```
  #
  abstract class AModel

    # Declares managed `created_at` / `updated_at : Time?` columns.
    macro timestamps
      field created_at : Time? = nil
      field updated_at : Time? = nil

      before_create do
        now = Time.utc
        self.created_at = now
        self.updated_at = now
      end

      before_save { self.updated_at = Time.utc }
    end

  end


end
