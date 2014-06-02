require 'java'

$CLASSPATH << File.dirname(__FILE__) + "/"

$LOAD_PATH << File.dirname(__FILE__) + '/../lib'

require File.dirname(__FILE__) + '/../log4j/log4j-core-2.0-rc1.jar'
require File.dirname(__FILE__) + '/../log4j/log4j-api-2.0-rc1.jar'
