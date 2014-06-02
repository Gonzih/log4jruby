require 'spec_helper'

require 'log4jruby'

module Log4jruby
  describe Logger do
    context = Java::org.apache.logging.log4j.ThreadContext

    subject { Logger.get('Test', :level => :debug) }

    let(:log4j) { subject.log4j_logger}

    describe "mapping to Log4j Logger names" do
      it "should prepend 'jruby.' to specified name" do
        Logger.get('MyLogger').log4j_logger.name.should == 'jruby.MyLogger'
      end

      it "should translate :: into . (e.g. A::B::C becomes A.B.C)" do
        Logger.get('A::B::C').log4j_logger.name.should == "jruby.A.B.C"
      end
    end

    describe ".get" do
      it "should return one logger per name" do
        Logger.get('test').should be_equal(Logger.get('test'))
      end

      it "should accept attributes hash" do
        logger = Logger.get("loggex#{object_id}", :level => :fatal, :tracing => true)
        logger.log4j_logger.level.should == Java::org.apache.logging.log4j.Level::FATAL
        logger.tracing.should == true
      end
    end

    describe "root logger" do
      it "should be accessible via .root" do
        Logger.root.log4j_logger.name.should == 'jruby'
      end

      it "should always return same object" do
        Logger.root.should be_equal(Logger.root)
      end
    end

    specify "there should be only one logger per name(retrievable via Logger[name])" do
      Logger["A"].should be_equal(Logger["A"])
    end

    specify "the backing log4j Logger should be accessible via :log4j_logger" do
      Logger.get('X').log4j_logger.should be_instance_of(Java::org.apache.logging.log4j.core.Logger)
    end

    describe 'Rails logger compatabity' do
      it "should respond to <level>?" do
        [:debug, :info, :warn].each do |level|
          subject.respond_to?("#{level}?").should == true
        end
      end

      it "should respond to :level" do
        subject.respond_to?(:level).should == true
      end

      it "should respond to :flush" do
        subject.respond_to?(:flush).should == true
      end
    end

    describe "#level =" do
      describe 'accepts symbols or ::Logger constants' do
        [:debug, :info, :warn, :error, :fatal].each do |l|
          example ":#{l}" do
            subject.level = l
            subject.level.should == ::Logger.const_get(l.to_s.upcase)
          end
        end

        ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'].each do |l|
          example "::Logger::#{l}"  do
            level_constant = ::Logger.const_get(l.to_sym)
            subject.level = level_constant
            subject.level.should == level_constant
          end
        end
      end
    end

    describe '#level' do
      it 'returns ::Logger constant values' do
        subject.level = ::Logger::DEBUG
        subject.level.should == ::Logger::DEBUG
      end

      it 'inherits parent level when not explicitly set' do
        Logger.get('Foo', :level => :fatal)
        Logger.get('Foo::Bar').level.should == ::Logger::FATAL
      end
    end

    [:debug, :info, :warn, :error, :fatal].each do |level|
      describe "##{level}" do
        it "should stringify non-exception argument" do
          log4j.should_receive(level).with('7', nil)
          subject.send(level, 7)
        end

        it "should log message and backtrace for ruby exceptions" do
          log4j.should_receive(level).with(/some error.*#{__FILE__}/m, nil)
          begin
            raise "some error"
          rescue => e
            subject.send(level, e)
          end
        end

        it "should log ruby backtrace and wrapped Throwable for NativeExceptions" do
          log4j.should_receive(level).
            with(/not a number.*#{__FILE__}/m, instance_of(java.lang.NumberFormatException))

          begin
            java.lang.Long.new('not a number')
          rescue NativeException => e
            subject.send(level, e)
          end
        end

      end
    end

    [:debug, :info, :warn].each do |level|
      describe "##{level} with block argument" do
        it "should log return value of block argument if #{level} is enabled" do
          log4j.should_receive(:isEnabled).and_return(true)
          log4j.should_receive(level).with("test", nil)
          subject.send(level) { 'test' }
        end

        it "should not evaluate block argument if #{level} is not enabled" do
          log4j.should_receive(:isEnabled).and_return(false)
          subject.send(level) { raise 'block was called' }
        end
      end
    end

    describe '#tracing?', "should be inherited" do
      before do
        Logger.root.tracing = nil
        Logger.get("A::B").tracing = nil
        Logger.get("A").tracing = nil
      end

      it "should return false with tracing unset anywhere" do
        Logger['A'].tracing?.should == false
      end

      it "should return true with tracing explicitly set to true" do
        Logger.get('A', :tracing => true).tracing?.should == true
      end

      it "should return true with tracing unset but set to true on parent" do
        Logger.get('A', :tracing => true)
        Logger.get('A::B').tracing?.should == true
      end

      it "should return false with tracing unset but set to false on parent" do
        Logger.get('A', :tracing => false)
        Logger.get('A::B').tracing?.should == false
      end

      it "should return true with tracing unset but set to true on root logger" do
        Logger.root.tracing = true
        Logger.get('A::B').tracing?.should == true
      end
    end

    context "with tracing on" do
      before do
        subject.tracing = true
      end

      it "should set context lineNumber for duration of invocation" do
        line = __LINE__ + 5
        log4j.should_receive(:debug) do
          context.get('lineNumber').should == "#{line}"
        end

        subject.debug('test')

        context.get('lineNumber').should be_nil
      end

      it "should set context fileName for duration of invocation" do
        log4j.should_receive(:debug) do
          context.get('fileName').should == __FILE__
        end

        subject.debug('test')

        context.get('fileName').should be_nil
      end

      it "should not push caller info into context if logging level is not enabled" do
        log4j.stub(:isEnabled).and_return(false)

        context.stub(:put).and_raise("context was modified")

        subject.debug('test')
      end

      it "should set context methodName for duration of invocation" do
        def some_method
          subject.debug('test')
        end

        log4j.should_receive(:debug) do
          context.get('methodName').should == 'some_method'
        end

        some_method()

        context.get('methodName').should be_nil
      end
    end

    context "with tracing off" do
      before { subject.tracing = false }

      it "should set context with blank values" do
        log4j.should_receive(:debug) do
          context.get('fileName').should == ''
          context.get('methodName').should == ''
          context.get('lineNumber').should == ''
        end

        subject.debug('test')
      end
    end

    describe '#log_error(msg, error)' do
      it "should forward to log4j error(msg, Throwable) signature" do
        log4j.should_receive(:error).
        with('my message', instance_of(java.lang.IllegalArgumentException))

        subject.log_error('my message', java.lang.IllegalArgumentException.new)
      end
    end

    describe '#log_fatal(msg, error)' do
      it "should forward to log4j fatal(msg, Throwable) signature" do
        log4j.should_receive(:fatal).
        with('my message', instance_of(java.lang.IllegalArgumentException))

        subject.log_fatal('my message', java.lang.IllegalArgumentException.new)
      end
    end

    describe "#attributes =" do
      it "should do nothing(i.e. not bomb) if given nil" do
        subject.attributes = nil
      end

      it "should set values with matching setters" do
        subject.tracing = false
        subject.attributes = {:tracing => true}
        subject.tracing.should == true
      end

      it "should ignore values without matching setter" do
        subject.attributes = {:no_such_attribute => 'ignore' }
      end
    end
  end

end
