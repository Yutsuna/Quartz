module Quartz


  # Marks an instance variable as a Quartz model field.
  #
  # Applied automatically by the `AModel.field` macro. Kept as an extension
  # seam: future features (serialization, validations) can reflect on
  # annotated instance vars from inside method bodies via
  # `@type.instance_vars.select(&.annotation(Quartz::FField))`.
  annotation FField
  end


end
