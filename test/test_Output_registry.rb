#!/usr/bin/ruby

$: << "../lib"


require "runit/testcase"
require "runit/cui/testrunner"
require 'jiji/registry'
require "logger"
require "testutils"

# アウトプットのテスト(レジストリから取り出す)
class OutputregistryTest <  RUNIT::TestCase

  include Test::Constants

  def setup
    @dir = File.dirname(__FILE__) + "/OutputregistryTest"
    @registry = JIJI::Registry.new(@dir , nil)
    @mng = @registry[:process_manager]
  end

  def teardown
    begin
      @mng.stop
      begin
        @registry.permitter.close
      ensure
        begin
          @registry.client.close
        ensure
          @registry.server_logger.close
        end
      end
    ensure
      FileUtils.rm_rf "#{@dir}/logs"
      FileUtils.rm_rf "#{@dir}/process_logs"
    end
  end

  # outputに2重にアスペクトが適用され、実行時エラーになっていた不具合の回収確認テスト。
  def testCreate 
    out = @registry.output("rmt", "test_agent")
    out.time = Time.now
    out.get("foo").put( 1,2 )
    out.get("foo").put( 2,3 )
    
    out2 = @registry.output("rmt", "test_agent")
    out2.time = Time.now
    out2.get("foo").put( 2,3 )
  end
  
end