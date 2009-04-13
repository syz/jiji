#!/usr/bin/ruby

$: << "../lib"


require "runit/testcase"
require "runit/cui/testrunner"
require "jiji/process"
require 'jiji/agent/agent'
require 'jiji/agent/agent_manager'
require 'jiji/agent/agent_registry'
require 'jiji/agent/permitter'
require 'jiji/agent/util'
require "logger"
require "testutils"

# プロセスのテスト
class ProcessTest <  RUNIT::TestCase

  include Test::Constants

  def setup
    @dir = File.dirname(__FILE__) + "/ProcessTest.tmp"
    FileUtils.mkdir_p @dir

    @logger = Logger.new STDOUT

    # レジストリ
    @registry_mock = Object.new
    class << @registry_mock
      def output( agent_name, dir )
        return ["from_registry"]
      end
    end
  end

  def teardown
    FileUtils.rm_rf @dir
  end

  # 基本動作のテスト
  def test_basic

    # 新規に作成
    agent_mng = new_agent_mang

    p1 = JIJI::Process.new( "1", @dir, agent_mng, @logger, {}, @registry_mock )
    assert_equals p1.id, "1"
    assert_equals p1.props, {"agents"=>[]}
    assert_equals p1["x"], nil
    assert_equals p1.agent_manager, agent_mng
    assert_equals p1.outputs, {}

    p1["x"] = "xxx"
    assert_equals p1["x"], "xxx"

    # トレードのon/offを設定
    p1["trade_enable"] = false
    assert_equals p1["trade_enable"], false
    assert_equals p1.agent_manager.operator.trade_enable, false
    p1["trade_enable"] = true
    assert_equals p1["trade_enable"], true
    assert_equals p1.agent_manager.operator.trade_enable, true
    p1["trade_enable"] = false
    assert_equals p1["trade_enable"], false
    assert_equals p1.agent_manager.operator.trade_enable, false

    # エージェントの設定を変更
    agents = [
      {"id"=>"aaa",
       "name"=>"テストエージェント1",
       "class"=>"testclass@foo.rb",
       "class_name" => "testclass",
       "file_name" => "foo.rb",
       "description" => "説明",
       "property_def" => {"id"=>"x", "default"=>85 },
       "properties" => {"x"=>30, "y"=>40 }},
      {"id"=>"bbb",
       "name"=>"テストエージェント2",
       "class"=>"testclass2@foo.rb",
       "class_name" => "testclass",
       "file_name" => "foo.rb",
       "description" => "説明2",
       "property_def" => {"id"=>"x", "default"=>85 },
       "properties" => {"x"=>30, "y"=>41 }}
    ]

    # 追加
    p1["agents"] = agents
    assert_equals p1["agents"], agents
    assert_equals agent_mng.get("aaa").agent.cl, "testclass@foo.rb"
    assert_equals agent_mng.get("aaa").agent.properties, {"x"=>30, "y"=>40 }
    assert_equals agent_mng.get("bbb").agent.cl, "testclass2@foo.rb"
    assert_equals agent_mng.get("bbb").agent.properties, {"x"=>30, "y"=>41 }
    assert_equals p1.outputs, { "aaa"=>["out1","out2"], "bbb"=>["out1","out2"] }

    # 変更
    agents = [
      {"id"=>"aaa",
       "name"=>"テストエージェント1",
       "class"=>"testclass@foo.rb",
       "class_name" => "testclass",
       "file_name" => "foo.rb",
       "description" => "説明",
       "property_def" => {"id"=>"x", "default"=>85 },
       "properties" => {"x"=>50, "y"=>40 }},
      {"id"=>"bbb",
       "name"=>"テストエージェント4",
       "class"=>"testclass2@foo.rb",
       "class_name" => "testclass",
       "file_name" => "foo.rb",
       "description" => "説明2aaaaaa",
       "property_def" => {"id"=>"x", "default"=>85 },
       "properties" => {"x"=>60, "y"=>41 }}
    ]
    p1["agents"] = agents
    assert_equals p1["agents"], agents
    assert_equals agent_mng.get("aaa").agent.cl, "testclass@foo.rb"
    assert_equals agent_mng.get("aaa").agent.properties, {"x"=>50, "y"=>40 }
    assert_equals agent_mng.get("bbb").agent.cl, "testclass2@foo.rb"
    assert_equals agent_mng.get("bbb").agent.properties, {"x"=>60, "y"=>41 }
    assert_equals p1.outputs, { "aaa"=>["out1","out2"], "bbb"=>["out1","out2"] }

    # 削除
    agents = [
      {"id"=>"aaa",
       "name"=>"テストエージェント1",
       "class"=>"testclass@foo.rb",
       "class_name" => "testclass",
       "file_name" => "foo.rb",
       "description" => "説明",
       "property_def" => {"id"=>"x", "default"=>85 },
       "properties" => {"x"=>50, "y"=>41 }}
    ]
    p1["agents"] = agents
    assert_equals p1["agents"], agents
    assert_equals agent_mng.get("aaa").agent.cl, "testclass@foo.rb"
    assert_equals agent_mng.get("aaa").agent.properties, {"x"=>50, "y"=>41 }
    assert_equals agent_mng.get("bbb"), nil
    assert_equals p1.outputs, { "aaa"=>["out1","out2"] }

    # RMTモードで再読み込み
    # ファイルに保存された設定値が読み込まれる。また、エージェントがインスタンス化される
    agent_mng = new_agent_mang
    p1 = JIJI::Process.new( "1",  @dir, agent_mng, @logger, nil, @registry_mock, true )
    assert_equals p1.id, "1"
    assert_equals p1.agent_manager, agent_mng
    assert_equals p1["x"], "xxx"
    assert_equals p1["agents"], agents
    assert_equals agent_mng.get("aaa").agent.cl, "testclass@foo.rb"
    assert_equals agent_mng.get("aaa").agent.properties, {"x"=>50, "y"=>41 }
    assert_equals agent_mng.get("bbb"), nil
    assert_equals p1["trade_enable"], false
    assert_equals p1.agent_manager.operator.trade_enable, false
    assert_equals p1.outputs, { "aaa"=>["out1","out2"] }

    # バックテストモードで再読み込み
    # ファイルに保存された設定値が読み込まれるが、エージェントはインスタンス化されない
    agent_mng = new_agent_mang
    p1 = JIJI::Process.new( "1",  @dir, agent_mng, @logger, nil, @registry_mock, false )
    assert_equals p1.id, "1"
    assert_equals p1.agent_manager, agent_mng
    assert_equals p1["x"], "xxx"
    assert_equals p1["agents"], agents
    assert_equals agent_mng.get("aaa"), nil
    assert_equals agent_mng.get("bbb"), nil
    assert_equals p1["trade_enable"], false
    assert_equals p1.agent_manager.operator.trade_enable, false
    assert_equals p1.outputs, { "aaa"=> ["from_registry"] }

    # 別のプロセスを作成 / 設定値は別途保持される。
    agent_mng = new_agent_mang
    p2 = JIJI::Process.new( "2", @dir, agent_mng, @logger, {}, @registry_mock )
    assert_equals p2.id, "2"
    assert_equals p2.agent_manager, agent_mng
    assert_equals p2["x"], nil
    assert_equals p2["agents"], []
    assert_equals p2.outputs, { }

    # 作成の段階でエージェントを指定する
    agent_mng = new_agent_mang
    p3 = JIJI::Process.new( "3", @dir, agent_mng, @logger, {"agents"=>agents}, @registry_mock )
    assert_equals p3.id, "3"
    assert_equals p3.agent_manager, agent_mng
    assert_equals p3["x"], nil
    assert_equals p3["agents"], agents
    assert_equals agent_mng.get("aaa").agent.cl, "testclass@foo.rb"
    assert_equals agent_mng.get("aaa").agent.properties, {"x"=>50, "y"=>41 }
    assert_equals agent_mng.get("bbb"), nil
    assert_equals p3.outputs, { "aaa"=>["out1","out2"] }

  end

  # エージェントの作成でエラーになった場合のテスト
  def test_error
    agents = [
      {"id"=>"aaa",
       "name"=>"テストエージェント1",
       "class"=>"testclass@foo.rb",
       "class_name" => "testclass",
       "file_name" => "foo.rb",
       "description" => "説明",
       "property_def" => {"id"=>"x", "default"=>85 },
       "properties" => {"x"=>50, "y"=>41 }}
    ]

    # RMTで生成時にエラー
    # 再起動で失敗するのを防ぐため、エラーはログに出力された後、無視される。
    agent_mng = new_agent_mang
    p1 = JIJI::Process.new( "1", @dir, agent_mng, @logger, {"agents"=>agents}, @registry_mock, true )

    error_registry = RegistryMock.new
    class << error_registry
      def create(*args); raise "test"; end
    end
    # 再作成
    agent_mng = new_agent_mang(error_registry)
    p1 = JIJI::Process.new( "1", @dir, agent_mng, @logger, nil, @registry_mock, true )
    assert_equals p1.id, "1"
    assert_equals p1.agent_manager, agent_mng
    assert_equals p1["agents"], agents
    assert_equals agent_mng.get("aaa"), nil
    assert_equals agent_mng.get("bbb"), nil
    assert_equals p1["trade_enable"], nil
    assert_equals p1.agent_manager.operator.trade_enable, false
    assert_equals p1.outputs, { "aaa"=>["from_registry"] }

    # RMTでエージェントの追加時にエラー
    agents << {"id"=>"bbb",
       "name"=>"テストエージェント4",
       "class"=>"testclass2@foo.rb",
       "class_name" => "testclass",
       "file_name" => "foo.rb",
       "description" => "説明2aaaaaa",
       "property_def" => {"id"=>"x", "default"=>85 },
       "properties" => {"x"=>60, "y"=>41 }}
    begin
      p1["agents"] = agents
      fail
    rescue
    end

    # RMTでエージェントのプロパティ更新時にエラー
    agents2 = [
      {"id"=>"aaa",
       "name"=>"テストエージェント1",
       "class"=>"testclass@foo.rb",
       "class_name" => "testclass",
       "file_name" => "foo.rb",
       "description" => "説明",
       "property_def" => {"id"=>"x", "default"=>85 },
       "properties" => {"x"=>50, "y"=>41 }}
    ]
    error_registry = RegistryMock.new
    class << error_registry
      def create( cl, property )
        a = Agent.new( cl, property )
        class << a
          def properties=(props)
            raise "test"
          end
        end
        return a
      end
    end
    agent_mng = new_agent_mang(error_registry)
    p1 = JIJI::Process.new( "2", @dir, agent_mng, @logger, {"agents"=>agents2}, @registry_mock, true )
    assert_equals p1["agents"], agents2
    assert_equals agent_mng.get("aaa").agent.cl, "testclass@foo.rb"
    assert_equals agent_mng.get("aaa").agent.properties, {"x"=>50, "y"=>41 }
    assert_equals agent_mng.get("bbb"), nil
    assert_equals p1.outputs, { "aaa"=>["out1","out2"] }

    begin
      p1["agents"] = [
        {"id"=>"aaa",
         "name"=>"テストエージェント1",
         "class"=>"testclass@foo.rb",
         "class_name" => "testclass",
         "file_name" => "foo.rb",
         "description" => "説明",
         "property_def" => {"id"=>"x", "default"=>85 },
         "properties" => {"x"=>50, "y"=>31 }}
      ]
      fail
    rescue
    end
    assert_equals p1["agents"], agents2
    assert_equals agent_mng.get("aaa").agent.cl, "testclass@foo.rb"
    assert_equals agent_mng.get("aaa").agent.properties, {"x"=>50, "y"=>41 }
    assert_equals agent_mng.get("bbb"), nil
    assert_equals p1.outputs, { "aaa"=>["out1","out2"] }

    # バックテストでエージェント生成時にエラー
    error_registry = RegistryMock.new
    class << error_registry
      def create; raise "test"; end
    end
    agent_mng = new_agent_mang(error_registry)
    begin
      JIJI::Process.new( "1", @dir, agent_mng, @logger, {"agents"=>agents}, @registry_mock, false )
      fail
    rescue
    end
  end

  # エージェントマネージャを再作成する
  def new_agent_mang( agent_registory=RegistryMock.new )
    agent_mng = JIJI::AgentManager.new( "aaa", agent_registory, Logger.new(STDOUT))
    agent_mng.operator = Struct.new(:trade_enable).new(true)
    agent_mng.conf = CONF
    agent_mng.conf.set( [:agent,:safe_level], 0)
    agent_mng.registry = @registry_mock
    return agent_mng
  end

  class Agent
    include JIJI::Agent

    def initialize( cl, properties )
      @cl = cl
      @properties = properties
    end

    # 設定されたプロパティを取得する
    def properties
      @properties
    end
    # プロパティを設定する
    def properties=( properties )
      @properties = properties
    end
    def output
      ["out1","out2"]
    end
    attr :cl, true
  end

  class RegistryMock
    def create( cl, property )
      Agent.new( cl, property )
    end
  end

end