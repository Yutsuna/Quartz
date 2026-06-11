require "./Model"

module Quartz


  # Macro-time model registry.
  #
  # These are macros (not methods) on purpose: they re-expand at every call
  # site, so in the REPL they always reflect the classes defined so far in
  # the session.
  #
  # A runtime registry filled from `macro inherited` would not work.
  # Class-body side effects emitted by `inherited` are skipped by the
  # interpreter on Crystal 1.20.2
  #
  # Every concrete model class known at the call site, as a stable
  # `Array(Quartz::AModel.class)` (empty when no model is defined yet).
  #
  # ```
  # Quartz.models # => [User, Post]
  # ```
  macro models
    {% subclasses = Quartz::AModel.all_subclasses.reject(&.abstract?) %}
    [{{subclasses.splat}}] of Quartz::AModel.class
  end

  # Names of every concrete model class known at the call site.
  #
  # ```
  # Quartz.model_names # => ["User", "Post"]
  # ```
  macro model_names
    Quartz.models.map(&.name)
  end


end
