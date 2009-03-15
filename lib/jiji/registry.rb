
require 'rubygems'
require 'yaml'
require 'needle'
require 'jiji/collector'
require 'jiji/configuration'
require 'jiji/observer'
require 'jiji/process'
require 'jiji/process_manager'
require 'jiji/agent/agent'
require 'jiji/agent/agent_manager'
require 'jiji/agent/agent_registry'
require 'jiji/agent/permitter'
require 'jiji/agent/util'
require 'jiji/output'
require 'jiji/operator'
require 'jiji/single_click_client'
require "jiji/dao/rate_dao"
require "jiji/dao/trade_result_dao"
require 'logger'
require 'fileutils'
require 'jiji/util/synchronize_interceptor'

require 'jiji/service/agent_service'
require 'jiji/service/hello_service'
require 'jiji/service/rate_service'
require 'jiji/service/trade_result_service'
require 'jiji/service/output_service'
require 'jiji/service/process_service'
require 'jiji/service/system_service'

module JIJI

  #
  # レジストリ
  #
  class Registry

    def initialize(base, server=nil)
      @registry = Needle::Registry.new {|r|

        # ベースディレクトリ
        r.register( :base_dir) { base }
        # サーバー
        r.register( :server) { server }

        # 設定値
        r.register( :conf ) {
          JIJI::Configuration.new r.base_dir + "/conf/configuration.yaml"
        }
        # アカウント(とりあえず設定ファイルから読む)
        r.register( :account ) {
          conf = r.conf
          accountClass = Struct.new(:user, :password)
          accountClass.new(
            conf.get([:securities,:account,:user], ""),
            conf.get([:securities,:account,:password], ""))
        }

        # レート一覧置き場
        r.register( :rate_dir ) {
          dir = r.base_dir + "/" + r.conf.get([:dir,:rate_data], "rate_datas")
          FileUtils.mkdir_p dir
          dir
        }
        # プロセスデータ置き場
        r.register( :process_dir ) {
	        process_dir = "#{r.base_dir}/#{r.conf.get([:dir,:process_log], "process_logs")}"
	        FileUtils.mkdir_p process_dir
          process_dir
        }

        # ロガー
        r.register( :server_logger ) {
          dir = "#{r.base_dir}/#{r.conf.get([:dir,:log], "logs")}"
          FileUtils.mkdir_p dir
          Logger.new( dir + "/log.txt", 10, 512*1024 )
        }
        r.register( :process_logger, :model=>:multiton_initialize ) {|c,p,id|
          dir = "#{r.process_dir}/#{id}"
          FileUtils.mkdir_p dir
          c = Logger.new( dir + "/log.txt", 10, 512*1024 )
          r.permitter.proxy( c, [/^(info|debug|warn|error|fatal|close)$/] )
        }

        # クライアント
        r.register( :client ) {
          JIJI::SingleClickClient.new( r.account, r.conf, r.server_logger )
        }
        # Permitter
        r.register( :permitter ) {
          JIJI::Permitter.new( 5, 0 )
        }

        # Dao
        r.register( :scales ) {
          ["1m", "5m", "10m", "30m", "1h", "6h", "1d", "2d", "5d"]
        }
        r.register( :rate_dao ) {
          JIJI::Dao::RateDao.new( r.rate_dir, r.scales )
        }
        r.register( :trade_result_dao, :model=>:multiton_initialize ) {|c,p,id|
          dir = "#{r.process_dir}/#{id}/trade"
          FileUtils.mkdir_p dir
          JIJI::Dao::TradeResultDao.new( dir, r.scales )
        }

        # アウトプット
        r.register( :output, :model=>:multiton_initialize ) {|c,p,id,agent_name|
          dir = "#{r.process_dir}/#{id}/out"
          FileUtils.mkdir_p dir

          c = JIJI::Output.new(agent_name, dir, r.scales)
          r.permitter.proxy( c, [/^(get|put|<<)$/], [/^get$/] )
        }

        # オブザーバー
        r.register( :rmt_observer_manager ) {
          JIJI::WorkerThreadObserverManager.new([
            r.rate_dao, r.agent_manager("rmt",true)
          ], r.process_logger("rmt"))
        }
        r.register( :backtest_observer_manager, :model=>:multiton_initialize ) {|c,p,id|
          JIJI::ObserverManager.new( [r.agent_manager(id, false)], r.process_logger(id))
        }

        # エージェントマネージャ
        r.register( :agent_manager, :model=>:multiton_initialize ) {|c,p,id,failsafe|
          c = JIJI::AgentManager.new( id, r.agent_registry, r.process_logger(id), failsafe )
          c.operator = r.operator(id, false, nil) # 作成段階では常に取引は行なわない。
          c.client   = r.client
          c.registory = r
          c.conf = r.conf
          c.trade_result_dao = r.trade_result_dao(id)
          c
        }
        r.intercept( :agent_manager ).with {
          SynchronizeInterceptor
        }.with_options( :id=>:agent_manager )

        # エージェントレジストリ
        r.register( :agent_registry ) {
          dir = "#{r.base_dir}/#{r.conf.get([:dir,:agent], "agents")}"
          sdir = "#{r.base_dir}/#{r.conf.get([:dir,:shared_lib], "shared_lib")}"
          FileUtils.mkdir_p dir
          FileUtils.mkdir_p sdir
          c = JIJI::AgentRegistry.new( dir, sdir )
          c.conf = r.conf
          c.load_all
          c
        }

        # オペレーター
        r.register( :operator, :model=>:multiton_initialize ) {|c,p,id,trade_enable,money|
          c = JIJI::RmtOperator.new(r.client, r.process_logger(id), r.trade_result_dao(id), trade_enable, money)
          c.conf = r.conf
          r.permitter.proxy( c, [/^(sell|buy|commit)$/], [/^(sell|buy)$/])
        }

        # コレクター
        r.register( :rmt_collector ) {
          c = JIJI::Collector.new
          c.observer_manager = r.rmt_observer_manager
          c.conf      = r.conf
          c.logger    = r.process_logger("rmt")
          c.client    = r.client
          c
        }
        r.register( :backtest_collector, :model=>:multiton_initialize ) {|c,p,id, start_date, end_date|
          c = JIJI::BackTestCollector.new( r.rate_dao, start_date, end_date )
          c.observer_manager = r.backtest_observer_manager(id)
          c.conf      = r.conf
          c.logger    = r.process_logger(id)
          c.client    = r.client
          c
        }

        # RMTプロセス
        r.register( :rmt_process ) {
          c = JIJI::Process.new("rmt", r.process_dir, r.agent_manager("rmt",true), nil, true)
          c.observer_manager = r.rmt_observer_manager
          c.collector = r.rmt_collector
          c
        }
        # バックテストプロセス
        r.register( :backtest_process, :model=>:multiton_initialize ) {|c,p,id, props|
          # 既存のバックテストを読み込む場合、プロパティはnil
          # このときエージェントの初期化で失敗しても無視する。(テスト実行後にエージェントが書き換えられた場合に起こりえる。)
          c = JIJI::Process.new(id, r.process_dir, r.agent_manager(id,false), props, props == nil)
          c.observer_manager = r.backtest_observer_manager(id)
          c.collector = r.backtest_collector(id,
            Time.at( c["start_date"]), Time.at( c["end_date"]))
          c
        }

        # プロセスマネージャ
        r.register( :process_manager ) {
          c = JIJI::ProcessManager.new( r )
          c.conf = r.conf
          c
        }
        r.intercept( :process_manager ).with {
          SynchronizeInterceptor
        }.with_options( :id=>:process_manager )

        # サービス
        r.register( :hello_service ) {
          JIJI::Service::HelloService.new
        }
        r.register( :agent_service ) {
          c = JIJI::Service::AgentService.new
          c.agent_registry = r.agent_registry
          c.process_manager = r.process_manager
          c
        }
        r.register( :rate_service ) {
          c = JIJI::Service::RateService.new
          c.rate_dao = r.rate_dao
          c
        }
        r.register( :trade_result_service ) {
          c = JIJI::Service::TradeResultService.new
          c.process_manager = r.process_manager
          c
        }
        r.register( :output_service ) {
          c = JIJI::Service::OutputService.new
          c.process_manager = r.process_manager
          c.process_dir = r.process_dir
          c
        }
        r.register( :process_service ) {
          c = JIJI::Service::ProcessService.new
          c.process_manager = r.process_manager
          c
        }
        r.register( :system_service ) {
          c = JIJI::Service::SystemService.new
          c.server = r.server
          c
        }
      }
    end

    def method_missing(name, *args)
      @registry.send( name, *args )
    end

    def [](name)
      @registry[name]
    end

  end

end