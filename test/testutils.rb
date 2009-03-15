
$: << "../lib"


require "rubygems"
require "runit/testcase"
require "runit/cui/testrunner"
require "jiji/configuration"
require "fileutils"
require "logger"
require 'jiji/util/json_rpc_requestor'

# テスト用ユーティリティなど。
module Test
  module Constants
  
    # テスト用設定値
    CONF = JIJI::Configuration.new File.dirname(__FILE__) + "/test_configuration.yaml"
  
    ACCOUNT = Struct.new(:user,:password).new( 
      CONF.get([:securities, :account, :user], ""), 
      CONF.get([:securities, :account, :password], "") )
    
    Info = Struct.new( :trade_unit )
    Rate = Struct.new( :bid, :ask, :sell_swap, :buy_swap, :date )    
      
  end
  
  # サービスのテストの抽象基底クラス
  class AbstractServiceTest < RUNIT::TestCase
    def setup
    end
    def teardown
    end
  end
  
end