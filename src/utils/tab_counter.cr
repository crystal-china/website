require "./singleton"

class TabCounter
  include SINGLETON
  @init = 0
  @value : String?

  def value : String
    LOCK.synchronize do
      @init += 1
      @value || "tab#{@init}"
    end
  end
end
