require 'spec_helper'

require 'log4jruby'

describe '.enable_logger injects a logger' do
  class LogEnabledClass
    enable_logger

    def echo(s)
      logger.debug(s)
    end
  end

  specify 'lo4j logger is named for class' do
    LogEnabledClass.logger.log4j_logger.name.should include('LogEnabledClass')
  end

  specify 'logger is available to instance' do
    Log4jruby::Logger.any_instance.should_receive(:debug).with('foo')
    LogEnabledClass.new.echo('foo')
  end
end
