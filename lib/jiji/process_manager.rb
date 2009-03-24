
require 'uuidtools'
require 'yaml'
require 'jiji/util/fix_yaml_bug'

module JIJI
  class ProcessManager

    include Enumerable

    def initialize( registry )
      @registry = registry
      @rmt = @registry.rmt_process
      @back_tests = {}

      @mutex = Mutex.new
      @running = nil # 実行中のテスト
      @waiting = [] # 待機中のテスト

      # 既存のバックテスト一覧を読み込む
      Dir.glob( "#{registry.process_dir}/*" ) {|d|
        next unless File.directory? d
        next unless File.exist? "#{d}/props.yaml"
        id = File.basename(d)
        next if id == "rmt"
        @back_tests[id] = @registry.backtest_process(id, nil )
      }
    end

    # RMTプロセスをスタートする
    def start
      if @conf.get([:collector,:collect], true )
        @rmt.start
      end
    end

    # すべてのプロセスを停止する
    def stop
      @stoped = true
      @registry.operator( "rmt", false, nil).stop
      @rmt.stop
      @mutex.synchronize {
        @waiting.each {|i| 
          i.collector.listeners.delete(self)
          i.stop 
        }
        @waiting.clear
        if @running != nil
          @running.collector.listeners.delete(self)
          @running.stop
          @running = nil
        end
      }
    end

    # バックテストプロセスを列挙する
    def each( &block )
      @back_tests.each_pair {|k,v|
        yield v
      }
    end

    # プロセスを取得する
    def get( id )
      unless id == "rmt" || @back_tests.key?(id)
        raise UserError.new( JIJI::ERROR_NOT_FOUND, "process not found")
      end
      id == "rmt" ? @rmt : @back_tests[id]
    end

     # プロセスの設定を更新する。
     def set( process_id, setting )
        p = get( process_id );
        setting.each_pair {|k,v|
          case k
            when "name"
              p["name"] = v
            when "trade_enable"
              p["trade_enable"] = v if process_id == "rmt" # バックテストの変更は許可しない。
            when "agents"
              p["agents"] = v
          end
        }
      end

    # バックテストプロセスを新規に作成する
    def create_back_test( name, memo, start_date, end_date, agent_properties )

      id = UUID.random_create().to_s

      # プロパティを記録
      props = {
        "id"=>id,
        "name"=>name,
        "memo"=>memo,
        "create_date"=>Time.now.to_i,
        "start_date"=>start_date.to_i,
        "end_date"=>end_date.to_i,
        "agents"=>agent_properties,
        "state"=>:WAITING
      }
      begin
        btp = @registry.backtest_process(id, props )
        @mutex.synchronize {
          if @running == nil
            @running = btp
            @running.collector.listeners << self
            @running.start
          else
            @waiting << btp
          end
        }
      rescue Exception
        begin
          btp.stop
        rescue Exception
        ensure
          FileUtils.rm_rf "#{@registry.process_dir}/#{id}"
        end
        raise $!
      end

      @back_tests[id] = btp
      return {
       "id"=>id,
       "name"=>name,
       "create_date"=>Time.now.to_i
      }
    end

    # バックテストプロセスを再起動する
    def restart_test( id, agent_properties )
      unless id == "rmt" || @back_tests.key?(id)
        raise UserError.new( JIJI::ERROR_NOT_FOUND, "process not found")
      end
      p = get(id)
      FileUtils.rm_rf back_test_dir(id)
      props = {
        "id"=>id,
        "name"=>p["name"],
        "memo"=>p["memo"],
        "create_date"=>p["create_date"],
        "start_date"=>p["start_date"],
        "end_date"=>p["end_date"],
        "agent_properties"=>agent_properties
      }
      btp = @registry.back_test_process(id, props )
      btp.start

      @back_tests[id] = btp
      id
    end

    # バックテストプロセスを削除する
    # ログファイルもすべて削除。
    def delete_back_test( id )
      unless id == "rmt" || @back_tests.key?(id)
        raise UserError.new( JIJI::ERROR_NOT_FOUND, "process not found")
      end
      @mutex.synchronize {
        if @running != nil && @running["id"] == id
          @running.collector.listeners.delete(self)
          @running.stop 
          unless @waiting.empty?
            @running = @waiting.shift
            @running.collector.listeners << self
            @running.start
          else
            @running = nil
          end
        else
          # 待機中であればキューから除外。
          @waiting = @waiting.reject{|i| i.id == id }
        end
      }
      @back_tests.delete( id )
      FileUtils.rm_rf "#{@registry.process_dir}/#{id}"
    end

    # コレクターの終了通知を受け取る
    def on_finished( state, now )
      @mutex.synchronize {
        unless @waiting.empty?
          @running = @waiting.shift
          @running.collector.listeners << self
          @running.start
        else
          @running = nil
        end
      }
    end

    attr :registry, true
    attr :conf, true
  end
end