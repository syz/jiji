#!/usr/bin/ruby

$: << "../lib"


clazz = class << Thread; self; end
clazz.__send__(:alias_method, :start_org, :start )
def Thread.start(*args, &b)
  Thread.start_org( caller, *args) {|stack, *arg|
      Thread.current[:stack] = stack
      yield( *arg )
  }
end
def Thread.fork(*args, &b)
  Thread.start_org( caller, *args) {|stack, *arg|
      Thread.current[:stack] = stack
      yield( *arg )
  }
end
def Thread.new(*args, &b)
  Thread.start_org( caller, *args) {|stack, *arg|
      Thread.current[:stack] = stack
      yield( *arg )
  }
end

require "runit/testcase"
require "runit/cui/testrunner"
require 'jiji/registry'
require "logger"
require "testutils"

# プロセスマネージャのテスト
class ProcessManagerTest <  RUNIT::TestCase

  include Test::Constants

  def setup
    @dir = File.dirname(__FILE__) + "/ProcessManagerTest"
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
#      Thread.list.each {|t|
#        puts "---#{t}"
#        puts t[:stack]
#      }
    ensure
      FileUtils.rm_rf "#{@dir}/logs"
      FileUtils.rm_rf "#{@dir}/process_logs"
    end
  end

  def test_basic
    @mng.start
    agents = [{
      "name" => "aaa",
      "class" => "MovingAverageAgent@moving_average.rb",
      "id"=> "44c0d256-8994-4240-a6c6-8d9546aef8c4",
      "properties" =>  {
          "period" => 10,
          "short" => 25,
          "long" => 75
       }
    }]

    # プロセスを追加
    pid = @mng.create_back_test( "test", "memo", Time.gm( 2008, 8, 21 ).to_i, Time.gm( 2008, 8, 22 ).to_i, agents )["id"]
    sleep 0.1

    # プロセスを取得
    process = @mng.get( pid )
    assert_equals process.state, :RUNNING
    assert_not_nil process.progress
    assert_equals process.id, pid
    assert_equals process["name"], "test"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]

    # 実行完了を待つ
    sleep 1 while   @mng.get( pid ).state == :RUNNING

    assert_equals process.state, :FINISHED
    assert_not_nil process.progress
    assert_equals process.id, pid
    assert_equals process["name"], "test"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]

    #別のプロセスを追加
    pid2 = @mng.create_back_test( "test2", "memo", Time.gm( 2008, 8, 21 ).to_i, Time.gm( 2008, 8, 22 ).to_i, agents )["id"]
    sleep 1

    process = @mng.get( pid )
    assert_equals process.state, :FINISHED
    assert_not_nil process.progress
    assert_equals process.id, pid
    assert_equals process["name"], "test"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]

    process = @mng.get( pid2 )
    assert_equals process.state, :RUNNING
    assert_not_nil process.progress
    assert_equals process.id, pid2
    assert_equals process["name"], "test2"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]
    
    # 停止
    @mng.stop
    
    process = @mng.get( pid )
    assert_equals process.state, :FINISHED
    assert_not_nil process.progress
    assert_equals process.id, pid
    assert_equals process["name"], "test"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]

    process = @mng.get( pid2 )
    assert_equals process.state, :CANCELED
    assert_not_nil process.progress
    assert_equals process.id, pid2
    assert_equals process["name"], "test2"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]


    # マネージャを再作成 / プロセスがローカルのファイルより復元される
    recreate_registry
    @mng = @registry[:process_manager]

    process = @mng.get( pid )
    assert_equals process.state, :FINISHED
    assert_not_nil process.progress
    assert_equals process.id, pid
    assert_equals process["name"], "test"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]

    process = @mng.get( pid2 )
    assert_equals process.state, :CANCELED
    assert_not_nil process.progress
    assert_equals process.id, pid2
    assert_equals process["name"], "test2"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]


    # プロセスを削除
    @mng.delete_back_test( pid )
    assert_process_not_found(pid)

    process = @mng.get( pid2 )
    assert_equals process.state, :CANCELED
    assert_not_nil process.progress
    assert_equals process.id, pid2
    assert_equals process["name"], "test2"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]

    @mng.delete_back_test( pid2 )
    assert_process_not_found(pid2)

    # マネージャを再作成 / 削除されたデータは消えている筈
    recreate_registry
    @mng = @registry[:process_manager]

    assert_process_not_found(pid)
    assert_process_not_found(pid2)

    # 実行中に削除
    pid3 = @mng.create_back_test( "test3", "memo", Time.gm( 2008, 8, 21 ).to_i, Time.gm( 2008, 8, 22 ).to_i, agents )["id"]
    sleep 0.1

    process = @mng.get( pid3 )
    assert_equals process.state, :RUNNING
    assert_not_nil process.progress
    assert_equals process.id, pid3
    assert_equals process["name"], "test3"
    assert_equals process["memo"], "memo"
    assert_equals process["start_date"], Time.gm( 2008, 8, 21 ).to_i
    assert_equals process["end_date"], Time.gm( 2008, 8, 22 ).to_i
    assert_not_nil process["create_date"]

    @mng.delete_back_test( pid3 )
    assert_process_not_found(pid3)

    # マネージャを再作成 / 削除されたデータは消えている筈
    recreate_registry
    @mng = @registry[:process_manager]
    assert_process_not_found(pid3)

  end

  #
  #複数プロセスを同時に起動するテスト。
  #
  def test_multi_process
    @mng.start
    agents = [{
      "name" => "aaa",
      "class" => "MovingAverageAgent@moving_average.rb",
      "id"=> "44c0d256-8994-4240-a6c6-8d9546aef8c4",
      "properties" =>  {
          "period" => 10,
          "short" => 25,
          "long" => 75
       }
    }]

    # プロセスを追加
    pid = @mng.create_back_test( "test", "memo", Time.gm( 2008, 8, 21 ).to_i, Time.gm( 2008, 8, 22 ).to_i, agents )["id"]
    sleep 1

    # プロセスを取得
    process = @mng.get( pid )
    assert_equals process.state, :RUNNING
    assert_not_nil process.progress
    assert_equals process.id, pid

    #別のプロセスを追加
    pid2 = @mng.create_back_test( "test2", "memo", Time.gm( 2008, 8, 21 ).to_i, Time.gm( 2008, 8, 22 ).to_i, agents )["id"]
    sleep 1

    #別のプロセスは待機中になる。
    process = @mng.get( pid2 )
    assert_equals process.state, :WAITING
    assert_not_nil process.progress
    assert_equals process.id, pid2

    process = @mng.get( pid )
    assert_equals process.state, :RUNNING
    assert_not_nil process.progress
    assert_equals process.id, pid

    # 実行完了を待つ
    sleep 1 while   @mng.get( pid ).state == :RUNNING

    process = @mng.get( pid )
    assert_equals process.state, :FINISHED
    assert_not_nil process.progress
    assert_equals process.id, pid

    sleep 1

    #別のプロセスが開始される。
    process = @mng.get( pid2 )
    assert_equals process.state, :RUNNING
    assert_not_nil process.progress
    assert_equals process.id, pid2

    # 別のプロセスを追加して削除
    pid3 = @mng.create_back_test( "test3", "memo", Time.gm( 2008, 8, 21 ).to_i, Time.gm( 2008, 8, 22 ).to_i, agents )["id"]
    sleep 1
    process = @mng.get( pid3 )
    assert_equals process.state, :WAITING
    assert_not_nil process.progress
    assert_equals process.id, pid3
    
    @mng.delete_back_test( pid3 )
    assert_process_not_found(pid3)
    
    sleep 1 while   @mng.get( pid2 ).state == :RUNNING

    process = @mng.get( pid2 )
    assert_equals process.state, :FINISHED
    assert_not_nil process.progress
    assert_equals process.id, pid2
    
    sleep 10
    
    ##  待機状態のまま再起動
    # プロセスを追加
    pid4 = @mng.create_back_test( "test4", "memo", Time.gm( 2008, 8, 21 ).to_i, Time.gm( 2008, 8, 22 ).to_i, agents )["id"]
    sleep 10

    #別のプロセスを追加
    pid5 = @mng.create_back_test( "test5", "memo", Time.gm( 2008, 8, 21 ).to_i, Time.gm( 2008, 8, 22 ).to_i, agents )["id"]

    process = @mng.get( pid4 )
    assert_equals process.state, :RUNNING
    assert_not_nil process.progress
    assert_equals process.id, pid4
    
    process = @mng.get( pid5 )
    assert_equals process.state, :WAITING
    assert_not_nil process.progress
    assert_equals process.id, pid5
    
    recreate_registry
    @mng = @registry[:process_manager]
    
    # 実行中のものも待機中のものもキャンセル状態になる。
    process = @mng.get( pid4 )
    assert_equals process.state, :CANCELED
    assert_not_nil process.progress
    assert_equals process.id, pid4
    
    process = @mng.get( pid5)
    assert_equals process.state, :CANCELED
    assert_not_nil process.progress
    assert_equals process.id, pid5    
  end

  def recreate_registry
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
      return @registry = JIJI::Registry.new(@dir , nil)
    end
  end

  # プロセスが存在しないことを確認する。
  def assert_process_not_found( pid )
     begin
      @mng.get( pid )
      fail
    rescue JIJI::UserError
      assert_equals JIJI::ERROR_NOT_FOUND, $!.code
    end
  end

end