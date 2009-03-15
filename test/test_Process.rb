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
  end

  def teardown
    FileUtils.rm_rf @dir
  end

  def test_basic

    # 新規に作成
    agent_mng = JIJI::AgentManager.new( "aaa", RegistryMock.new, Logger.new(STDOUT))
    agent_mng.operator = Struct.new(:trade_enable).new(true)
    agent_mng.conf = CONF
    agent_mng.conf.set( [:agent,:safe_level], 0)

    registory_mock = Object.new
    class << registory_mock
      def output( agent_name, dir )
        output = JIJI::Output.new( agent_name, "#{dir}/out" )
        return output
      end
    end
    agent_mng.registory = registory_mock

    p1 = JIJI::Process.new( "1", @dir, agent_mng, {} )
    assert_equals p1.id, "1"
    assert_equals p1.props, {"agents"=>[]}
    assert_equals p1["x"], nil
    assert_equals p1.agent_manager, agent_mng

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


    # 再読み込み / ファイルに保存された設定値が読み込まれる。
    p1 = JIJI::Process.new( "1",  @dir, agent_mng )
    assert_equals p1.id, "1"
    assert_equals p1.agent_manager, agent_mng
    assert_equals p1["x"], "xxx"
    assert_equals p1["agents"], agents
    assert_equals agent_mng.get("aaa").agent.cl, "testclass@foo.rb"
    assert_equals agent_mng.get("aaa").agent.properties, {"x"=>50, "y"=>41 }
    assert_equals agent_mng.get("bbb"), nil
    assert_equals p1["trade_enable"], false
    assert_equals p1.agent_manager.operator.trade_enable, false

    # 別のプロセスを作成 / 設定値は別途保持される。
    p2 = JIJI::Process.new( "2", @dir, agent_mng, {} )
    assert_equals p2.id, "2"
    assert_equals p2.agent_manager, agent_mng
    assert_equals p2["x"], nil
    assert_equals p2["agents"], []

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
    attr :cl, true
  end

  class RegistryMock
    def create( cl, property )
      Agent.new( cl, property )
    end
  end

end