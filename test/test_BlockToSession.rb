#!/usr/bin/ruby

$: << "../lib"


require "runit/testcase"
require "runit/cui/testrunner"
require 'jiji/util/block_to_session'
require 'logger'
require 'csv'

class BlockToSessionTest <  RUNIT::TestCase
  
  def setup
  end

  def teardown
  end

  def test_basic
    
    buff = ""
    s = Session.new {|wait|
      do_as( "a", "b", buff ) {|a,b,log|
        log << "#{a}.#{b}.wait."
        wait.call( a, b, log )
      }
    }
    assert_equals buff, "start.a.b.wait."
    
    # リクエストを送る
    assert_equals "result", s.request {|a,b,log|
      log << "#{a}.#{b}.req."
      "result"
    }
    assert_equals buff, "start.a.b.wait.a.b.req."
    
    assert_equals "result2", s.request {|a,b,log|
      log << "#{a}.#{b}.req."
      "result2"
    }
    assert_equals buff, "start.a.b.wait.a.b.req.a.b.req."
    
    # リクエスト中にエラー#呼び出し元に伝搬される
    begin
      s.request {|a,b,log|
        raise NameError.new("test")
      }
      fail
    rescue NameError
    end
    begin
      s.request {|a,b,log|
        raise Exception.new
      }
      fail
    rescue Exception
    end
    
    s.close
    assert_equals buff, "start.a.b.wait.a.b.req.a.b.req.end."
    
  end

  def do_as( a,b,log ) 
    begin
      log << "start."
      yield a, b, log
    ensure
      log << "end."
    end
  end

end