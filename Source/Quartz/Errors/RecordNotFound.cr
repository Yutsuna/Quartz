module Quartz


# Raised by `Manager#find` and `Manager#find_by` when no record matches.
class RecordNotFound < AError

  def initialize( model : String, id : Int64 )
    super( "#{model} with id=#{id} not found" )
  end

  def initialize( model : String, criteria : String )
    super( "#{model} matching #{criteria} not found" )
  end

end



end
