require 'digest/sha1'

module Wolverine
  # {Script} represents a lua script in the filesystem. It loads the script
  # from disk and handles talking to redis to execute it. Error handling
  # is handled by {LuaError}.
  class Script

    # Loads the script file from disk and calculates its +SHA1+ sum.
    #
    # @param file [Pathname] the full path to the indicated file
    def initialize file
      @file = file
      @content = load_lua file
      @digest = Digest::SHA1.hexdigest @content
    end

    # Passes the script and supplied arguments to redis for evaulation.
    # It first attempts to use a script redis has already cached by using
    # the +EVALSHA+ command, but falls back to providing the full script
    # text via +EVAL+ if redis has not seen this script before. Future
    # invocations will then use +EVALSHA+ without erroring.
    #
    # @param redis [Redis] the redis connection to run against
    # @param args [*Objects] the arguments to the script
    # @return [Object] the value passed back by redis after script execution
    # @raise [LuaError] if the script failed to compile of encountered a
    #   runtime error
    def call redis, *args
      begin
        run_evalsha redis, *args
      rescue => e
        e.message =~ /NOSCRIPT/ ? run_eval(redis, *args) : raise
      end
    rescue => e
      if LuaError.intercepts?(e)
        raise LuaError.new(e, @file)
      else
        raise
      end
    end

    private

    def run_evalsha redis, *args
      redis.evalsha @digest, args.size, *args
    end

    def run_eval redis, *args
      redis.eval @content, args.size, *args
    end

    def load_lua file
      File.read file
    end

  end
end

