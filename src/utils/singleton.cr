module SINGLETON
  private LOCK = ::Mutex.new
  @@instance : self?

  macro included
    def self.instance : self
      @@instance || LOCK.synchronize do
        @@instance ||= new
      end
    end
  end
end
