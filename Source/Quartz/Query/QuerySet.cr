module Quartz

  # A `FQuerySet` wraps a single source proc `-> Array(T)` and builds a pipeline
  # by composition: every transform (`filter`, `exclude`, `order_by`, `limit`,
  # `offset`) returns a **new** `FQuerySet` whose source closes over the previous
  # one. Nothing runs until a terminal method calls the composed source.
  #
  # ```
  # adults = User.objects
  #   .filter { |u| u.age >= 18 }
  #   .exclude { |u| u.name == "admin" }
  #   .order_by { |u| u.age }
  #   .limit(10)
  #
  # adults.to_a    # => Array(User), evaluated here
  # adults.count   # => Int32
  # adults.first?  # => User?
  # ```
  #
  # Laziness and live semantics:
  #
  #   The root source (from `FManager#query`) is `-> { manager.all }`, re-read on
  #   every terminal call. A `FQuerySet` therefore reflects the manager's current
  #   contents at evaluation time and yields the same live record references as
  #   the manager (identity-map semantics, like `FManager#where`).
  #
  #   Each transform allocates a new `FQuerySet`; chaining never mutates the
  #   receiver, and no result is cached between terminal calls.
  #
  # `FQuerySet` includes `Enumerable(TInstance)`, so `map`, `select`, `reduce`, `to_a`,
  # etc. are all available on top of `each`.
  class FQuerySet( TInstance )

    include Enumerable( TInstance )

    def initialize( @source : -> Array( TInstance ) )
    end

  end


end
