module Quartz


abstract class AModel

 # Declares a typed model field with an optional default value:
 #
 # ```
 # field name : String
 # field age  : Int32 = 18
 # ```
 #
 # Generates an annotated `property` and registers the declaration in the
 # model's `QUARTZ_FIELDS` macro-time registry, from which the `finished`
 # hook generates the rest of the API.
 # Duplicate names (including against ancestor models) and the reserved name `id` are compile-time errors.
 macro field ( decl )
   {% unless decl.is_a?( TypeDeclaration ) %}
     {% raise "Quartz: `field` expects a type declaration like `field name : String`, got: #{decl}" %}
   {% end %}
   {% if decl.var.stringify == "id" %}
     {% raise "Quartz: `id` is reserved — every model already has `property id : Int64`" %}
   {% end %}
   {% if QUARTZ_FIELDS.any? { |f| f.var.stringify == decl.var.stringify } %}
     {% raise "Quartz: duplicate field `#{decl.var}` on #{@type}" %}
   {% end %}
   {% for ancestor in @type.ancestors %}
     {% if ancestor.has_constant?("QUARTZ_FIELDS") && ancestor.constant("QUARTZ_FIELDS").any? { |f| f.var.stringify == decl.var.stringify } %}
       {% raise "Quartz: field `#{decl.var}` on #{@type} is already declared on ancestor #{ancestor}" %}
     {% end %}
   {% end %}
   {% QUARTZ_FIELDS << decl %}
   @[Quartz::FField]
   property {{decl.var}} : {{decl.type}}
 end

 end


end
