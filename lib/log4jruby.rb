require 'java'

require File.dirname(__FILE__) + '/../log4j/log4j-core-2.0-rc1.jar'
require File.dirname(__FILE__) + '/../log4j/log4j-api-2.0-rc1.jar'

require 'log4jruby/logger'
require 'log4jruby/logger_for_class'

module Log4jruby

end

Object.class_eval do
  class << self
    def enable_logger
      send(:include, Log4jruby::LoggerForClass)
    end
  end
end
