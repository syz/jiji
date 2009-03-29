#!/usr/bin/ruby

$: << "../lib"


require "runit/testcase"
require "runit/cui/testrunner"
require 'jiji/agent/agent'
require 'jiji/agent/agent_manager'
require 'jiji/agent/agent_registry'
require 'jiji/agent/permitter'
require 'jiji/agent/util'
require "jiji/configuration"
require "jiji/collector"
require "jiji/dao/trade_result_dao"
require "fileutils"
require "testutils"
require "logger"

# AgentManager のテスト
class AgentManagerTest <  RUNIT::TestCase

  include JIJI::AgentUtil
  include Test::Constants

  def setup
    @dir = File.dirname(__FILE__) + "/agents"
    FileUtils.mkdir_p @dir

    @registry = JIJI::AgentRegistry.new( "#{@dir}/agents", "#{@dir}/sharedLib" )
    @registry.conf = CONF

    @permitter = JIJI::Permitter.new( 5, 0 )
    logger = Logger.new STDOUT
    logger = @permitter.proxy( logger, [/^(info|debug|warn|error|fatal)$/] )
    @client = JIJI::SingleClickClient.new( ACCOUNT, CONF, logger )

    @registry_mock = Object.new
    class << @registry_mock
      def output( agent_name, dir )
        output = JIJI::Output.new( agent_name, "#{dir}/out" )
        output = @permitter.proxy( output, [/^(get|each|put|<<)$/], [/^get$/] )
        return output
      end
      def permitter=(permitter)
        @permitter = permitter
      end
    end
    @registry_mock.permitter = @permitter

    operator = JIJI::RmtOperator.new( @client, logger, nil )
    operator.conf = CONF
    operator = @permitter.proxy( operator, [/^(sell|buy|commit)$/],[/^(sell|buy)$/])
    trade_result_dao = JIJI::Dao::TradeResultDao.new( "#{@dir}/trade_result" )

    @m = JIJI::AgentManager.new( "test_agentManager", @registry, logger)
    @m.operator = operator
    @m.conf = CONF
    @m.trade_result_dao = trade_result_dao
    @m.client = @client
    @m.registry = @registry_mock
  end

  def teardown
    @client.close
    @permitter.close
    FileUtils.rm_rf @dir
  end

  # 基本動作のテスト
  def test_basic
    str =<<-AGENT_STR
      class Foo
        include JIJI::Agent
        def initialize( )
          @log = []
        end
        def next_rates( rates )
          @log << rates[:EURJPY].bid
        end
        attr :log, true
      end
    AGENT_STR
    @registry.add_file( "foo.rb", str )

    agent1 = @registry.create( "Foo@foo.rb" )
    agent2 = @registry.create( "Foo@foo.rb" )

    @m.add( "テスト", agent1 )
    @m.add( "テスト2", agent2 )

    # 追加直後はactive
    assert_equals @m.on?( "テスト" ), true
    assert_equals @m.on?( "テスト2" ), true

    pair_infos = {
      ClickClient::FX::EURJPY => Info.new( 10000 )
    }
    @m.next_rates( JIJI::Rates.new( pair_infos, {
      :EURJPY => Rate.new( 100.0,100.05,-200,200,100 )
    }))
    @m.next_rates( JIJI::Rates.new( pair_infos, {
      :EURJPY => Rate.new( 110.0,110.05,-200,200,100 )
    }))
    assert_equals [[100.0, 110.0],[100.0, 110.0]], safe(4) {
      value = [agent1.log, agent2.log]
      agent1.log = []
      agent2.log = []
      value
    }

    # agent1をoff
    @m.off( "テスト" )
    assert_equals @m.on?( "テスト" ), false
    assert_equals @m.on?( "テスト2" ), true
    @m.next_rates( JIJI::Rates.new( pair_infos, {
      :EURJPY => Rate.new( 100.0,100.05,-200,200,100 )
    }))
    assert_equals [[],[100.0]], safe(4) {
      value = [agent1.log, agent2.log]
      agent1.log = []
      agent2.log = []
      value
    }

    # agent1を再度onにする
    @m.on( "テスト" )
    assert_equals @m.on?( "テスト" ), true
    assert_equals @m.on?( "テスト2" ), true
    @m.next_rates( JIJI::Rates.new( pair_infos, {
      :EURJPY => Rate.new( 100.0,100.05,-200,200,100 )
    }))
    assert_equals [[100.0],[100.0]], safe(4) {
      value = [agent1.log, agent2.log]
      agent1.log = []
      agent2.log = []
      value
    }

    # agent1を削除
    @m.remove( "テスト" )
    assert_equals @m.on?( "テスト2" ), true
    @m.next_rates( JIJI::Rates.new( pair_infos, {
      :EURJPY => Rate.new( 100.0,100.05,-200,200,100 )
    }))
    assert_equals [[],[100.0]], safe(4) {
      value = [agent1.log, agent2.log]
      agent1.log = []
      agent2.log = []
      value
    }
  end

  def test_error

    # 存在しないエージェントの操作
    begin
      @m.remove( "not found" )
      fail
    rescue JIJI::UserError
      assert_equals JIJI::ERROR_NOT_FOUND, $!.code
    end
    begin
      @m.on( "not found" )
      fail
    rescue JIJI::UserError
      assert_equals JIJI::ERROR_NOT_FOUND, $!.code
    end
    begin
      @m.off( "not found" )
      fail
    rescue JIJI::UserError
      assert_equals JIJI::ERROR_NOT_FOUND, $!.code
    end
    begin
      @m.on?( "not found" )
      fail
    rescue JIJI::UserError
      assert_equals JIJI::ERROR_NOT_FOUND, $!.code
    end

    # エージェントの2重登録
    @m.add( "テスト", TestAgent.new.taint )
    begin
      @m.add( "テスト", TestAgent.new.taint )
      fail
    rescue JIJI::UserError
      assert_equals JIJI::ERROR_ALREADY_EXIST, $!.code
    end
  end

  class TestAgent
    include JIJI::Agent
  end

  # outputsとoperatorを使ってみるテスト
  def test_use_outputs
    str =<<-AGENT_STR
      class Foo < JIJI::PeriodicallyAgent
        include JIJI::Agent
        def initialize( )
          super(0.1)
        end
        def next_period_rates( rates )

          out1 = output.get( "foo" )
          out1.put( :a, "aaaa" )
          out1.put( :b, "bbbb" )

          out2 = output.get( "var", :graph )
          out2 << 100
          out2 << 200

          logger.info "test"
          logger.warn IOError.new
          logger.error IOError.new
          logger.debug "test"

#          p1 = operator.sell(1)
#          p1.commit
#          p2 = operator.buy(1)
#          p2.commit
        end
        attr :log, true
      end
    AGENT_STR
    @registry.add_file( "foo.rb", str )

    agent = @registry.create( "Foo@foo.rb" )
    @m.add( "テスト", agent )

    pair_infos = {
      ClickClient::FX::EURJPY => Info.new( 10000 )
    }
    2.times {
	    @m.next_rates( JIJI::Rates.new( pair_infos, {
	      :EURJPY => Rate.new( 100.0,100.05,-200,200,100 )
	    }))
      sleep 0.5
    }

  end

  # 循環参照のテスト
  def test_recursive
    @registry.add_file( "AgentServiceTest_1.rb", BODY_O1 )
    @registry.add_file( "AgentServiceTest_2.rb", BODY_O2 )
    @m.each {|a|}
    @registry.inject([]) {|list,name|
      list << {
        "class_name"=>name,
        "properties"=>@registry.get_property_infos(name),
        "description"=>@registry.get_description(name)
      }
      list
    }
  end
  BODY_O1 =<<-BODY
    class TestAgent < JIJI::PeriodicallyAgent
      include JIJI::Agent
      def initialize
        @a = 1
        @b = "foo"
      end
      def property_infos
        super().concat [
          Property.new( "a", "aaa", 1 ),
          Property.new( "b", "bbb", "foo" )
        ]
      end
      def description
        "テスト\nテスト"
      end
      attr :a, true
      attr :b, true
    end
    module Test
      class TestAgent2
        include JIJI::Agent
        def description
          "テスト2"
        end
      end
    end
  BODY
  BODY_O2 =<<-BODY
    class TestAgent < JIJI::PeriodicallyAgent
      include JIJI::Agent
      def initialize
        @x = 1.0
        @y = "foo"
      end
      def property_infos
        super().concat [
          Property.new( "x", "aaa", 1.0 ),
          Property.new( "y", "bbb", "foo" )
        ]
      end
      def description
        "テスト"
      end
      attr :x, true
      attr :y, true
    end
  BODY
end

