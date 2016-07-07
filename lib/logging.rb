require 'logger'

module Logging
  def logger
    Logging.logger
  end
  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    @logger ||= Logger.new("log/debug.log")
  end
end
