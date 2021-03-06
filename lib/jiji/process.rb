
require 'jiji/agent/agent'
require 'jiji/agent/agent_manager'
require 'jiji/agent/agent_registry'
require 'jiji/agent/permitter'
require 'jiji/agent/util'
require 'jiji/util/file_lock'
require 'set'
require "thread"

module JIJI

  # プロセス
  class Process

    # コンストラクタ
    # 再起動後の復元の場合、プロパティを指定しないこと。この場合設定ファイルからロードされる。
    def initialize( id, process_dir, agent_manager, logger, props=nil, registry=nil, rmt=false )

      is_recreate = props == nil
      @logger = logger
      @registry = registry
      @id = id
      @agent_manager = agent_manager
      @process_dir = process_dir
      @started_mutex = Mutex.new
      @started_mutex.synchronize {
        @started= false
      }
      FileUtils.mkdir_p dir

      prop_file = "#{dir}/props.yaml"
      if !is_recreate
        @props = props
        @props["agents"] = [] unless @props.key? "agents"
        save_props
      else
        # 既存のプロセスの場合、ファイルから設定値を読み込む
        @props = {}
        lock {
          if ( File.exist? prop_file )
            @props = YAML.load_file prop_file
          end
        }
        @props["agents"] = [] unless @props.key? "agents"
      end

      # RMTまたは新規作成の場合はエージェントをロード
      # 再起動後の再作成時は、アウトプットのみ作成。
      @outputs = {}
      if rmt || !is_recreate
        load_agent(rmt) # リアル取引の再起動時は発生したエラーを無視する
      else
        if @props && @props["agents"]
          @props["agents"].each {|v|
            @outputs[v["id"]] = @registry.output( @id, v["name"] )
          }
        end
      end

      # 取引の有効状態を更新
      @agent_manager.operator.trade_enable =
        @props["trade_enable"] ? true : false

    end

    def start
      @started_mutex.synchronize {
        @started= true
        collector.listeners << self
        collector.start
      }
      # 状態を覚えておく
      self["state"] = collector.state
    end

    def stop
      @started_mutex.synchronize {
        if @started  # 起動していない場合は何もしない
          observer_manager.stop
          collector.stop

          # 状態を覚えておく
          self["state"] = collector.state
          @started = false
        else
          # 待機中の場合、キャンセル状態にする。
          if props["state"] == :WAITING
           self["state"] = :CANCELED
          end
        end
      }
      collector.logger.close
    end

    def state
      # 再起動後のバックテストは、コレクターが起動しない
      # 状態は記録されたデータから返す
      if !@started
        return props["state"] ? props["state"] : :CANCELED
      else
        return collector.state
      end
    end

    def progress
      # 再起動後のバックテストは、コレクターが起動しない
      # 進捗は常に100%とする
      if !@started
        100
      else
        collector.progress
      end
    end

    def []=(k,v)
      if ( k == "agents" )
        # エージェントの設定が更新された
        # 削除対象を特定するため、登録済みエージェントのIDのセットを作成
        set = agent_manager.inject(Set.new) { |s, pair| s << pair[0]  }
        v.each {|item|
          # プロパティの更新 / 対応するエージェントが存在しなければ作成。
          set_agent_properties( item["id"], item["properties"], item["class"] )
          set.delete item["id"]
        }
        # Mapに含まれていないエージェントは削除
        set.each { |id|
          agent_manager.remove( id )
          outputs.delete( id )
        }
      end
      if ( k == "trade_enable" )
        # 取引の有効状態を更新
        @agent_manager.operator.trade_enable = v ? true : false
      end
      @props[k] = v
      save_props
    end
    def [](k)
      @props[k]
    end

    # コレクターの終了通知を受け取る
    def on_finished( state, now )
      self["state"] = state
      agent_manager.flush( now )
    end


    attr :id, true
    attr :props, true
    attr :collector, true
    attr :observer_manager, true
    attr :process_dir, true
    attr :agent_manager, true
    attr :outputs, true
    attr :logger, true
    attr :registry, true

  private

    # 任意のエージェントの設定を更新する。
    # エージェントは初期化されない。propertiesのみ変更される。
    def set_agent_properties( id, props, cl )
      a = agent_manager.get(id)
      if a
        a.agent.properties = props
      else
        agent = agent_manager.agent_registry.create( cl, props )
        agent_manager.add( id, agent, props["name"] )
        @outputs[id] = agent.output
      end
    end

    def dir
      "#{@process_dir}/#{@id}"
    end
    def lock
      DirLock.new( dir ).writelock {
        yield
      }
    end
    def save_props
      prop_file = "#{dir}/props.yaml"
      lock {
        File.open( prop_file, "w" ) { |f|
          f.write( YAML.dump(@props) )
        }
      }
    end
    def load_agent( ignore_error=false  )
      @agent_manager.clear
      if @props && @props["agents"]
	      @props["agents"].each {|v|
          begin
	          agent = agent_manager.agent_registry.create( v["class"], v["properties"] )
	          agent_manager.add( v["id"], agent, v["name"] )
            @outputs[v["id"]] = agent.output
          rescue Exception
            unless ignore_error
              raise $!
            else
              @logger.error $!
            end
            # リアルトレードの場合、停止中にエージェントが破棄された場合を考慮し
            # エージェントの初期化で失敗しても無視し、出力先だけ作成
            @outputs[v["id"]] = @registry.output( @id, v["name"] )
          end
	      }
      end
    end
  end
end