#!/usr/bin/ruby

$: << "../lib"


require "runit/testcase"
require "runit/cui/testrunner"
require "jiji/configuration"
require "jiji/single_click_client"
require "testutils.rb"
require 'logger'
require 'csv'


#==SingleClickClientのテスト。
class SingleClickClientTest <  RUNIT::TestCase

  include Test::Constants

  def setup
    l = Logger.new STDOUT
    @c = JIJI::SingleClickClient.new( ACCOUNT, CONF, l )
  end

  def teardown
    @c.close
  end

  # 正常系のテスト
  def test_basic
    3.times {
      assert( @c.request {|fx|
        sleep 5
        fx.list_currency_pairs
      }.size > 0 )
    }
  end

  # リクエストでエラーとなった場合の操作
  def test_request_error
    begin
      @c.request {|fx|
        fx.list_orders( 1000 ) # エラーコードが不正。
      }
      fail
    rescue RuntimeError
    end

    # エラー後もリクエストを処理できる。
    3.times {
      assert( @c.request {|fx|
        sleep 5
        fx.list_currency_pairs
      }.size > 0)
    }
  end

  # out of sessionで再ログインのテスト
  def test_out_of_session
    init = false
    @c.request {|fx|
      begin
        raise "fail.Out Of Session." unless init
      ensure
        init = true
      end
    }

    # エラー後もリクエストを処理できる。
    3.times {
      assert( @c.request {|fx|
        sleep 5
        fx.list_currency_pairs
      }.size > 0)
    }
  end

  # 接続時にエラーになった場合
  # ログ出力がされることを確認。
  def test_login_error
    l = Logger.new STDOUT

    # 接続先が不正
    conf = JIJI::Configuration.new
    conf.set [:securities,:host], "notfound.com"
    c = JIJI::SingleClickClient.new( ACCOUNT, conf, l ) # エラーは発生しない。

    # 接続失敗状態でリクエストを送付すると、常に接続失敗の例外が返される。
    3.times {
      begin
        c.request {|fx| fx.list_currency_pairs }
        fail
      rescue JIJI::FatalError
        assert_equals JIJI::ERROR_NOT_CONNECTED, $!.code
      end
    }
    c.close
    
    # アカウントが不正
    account = Struct.new(:user,:password).new( "illegal", "illegal" )
    c = JIJI::SingleClickClient.new( account, CONF, l )
    
    # 接続失敗状態でリクエストを送付すると、常に接続失敗の例外が返される。
    3.times {
      begin
        c.request {|fx| fx.list_currency_pairs }
        fail
      rescue JIJI::FatalError
        assert_equals JIJI::ERROR_NOT_CONNECTED, $!.code
      end
    }
    c.close
    
  end
end