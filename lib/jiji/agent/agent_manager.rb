
require 'jiji/error'
require 'jiji/agent/agent'
require 'jiji/agent/agent_registry'
require 'jiji/agent/permitter'
require 'jiji/agent/util'
require 'jiji/output'
require 'jiji/operator'
require 'jiji/util/file_lock'
require 'set'

module JIJI

  class AgentManager

    include JIJI::AgentUtil
    include Enumerable
    State = Struct.new( :agent, :output, :active )

    def initialize( id, registry, logger, failsafe=true )
      @id = id
      @agents = {}
      @agent_registry = registry
      @logger = logger
      # エージェントでエラーが発生した場合にエラーを無視し実行を継続するか
      # true の場合、ログ出力後エラーを握って処理を継続(RMTはこちらで動作する)
      # false の場合、ログ出力後エラーを再スロー(バックテストはこちらで動作する)
      @failsafe = failsafe
    end

    # エージェントを追加する
    def add( id, agent, name="" )
      if @agents.key? id
        raise UserError.new( JIJI::ERROR_ALREADY_EXIST, "agent is already exist. id=#{id}")
      end
      output = @registry.output( @id, id )
      op = AgentOperator.new( @operator, name )
      safe( conf.get( [:agent,:safe_level], 4) ){
        agent.operator = op
        agent.logger = @logger
        agent.output = output
        agent.init
      }
      @agents[id] = State.new( agent, output, true )
    end

    # エージェントを破棄する
    def remove( name )
      unless @agents.key? name
        raise UserError.new( JIJI::ERROR_NOT_FOUND, "agent not found. name=#{name}")
      end
      @agents.delete name
    end

    # エージェントの一覧を得る
    def each( &block )
      @agents.each( &block )
    end

    # エージェントを得る
    def get( name )
      @agents[name]
    end

    # エージェントをすべて破棄する
    def clear
      @agents.clear
    end

    # エージェントへのイベント通知を開始する
    def on( agent_name )
      unless @agents.key? agent_name
        raise UserError.new( JIJI::ERROR_NOT_FOUND, "agent not found. name=#{agent_name}")
      end
      @agents[agent_name].active = true
    end

    # エージェントへのイベント通知を停止する
    def off( agent_name )
      unless @agents.key? agent_name
        raise UserError.new( JIJI::ERROR_NOT_FOUND, "agent not found. name=#{agent_name}")
      end
      @agents[agent_name].active = false
    end

    # エージェントへのイベント通知状態を取得する
    def on?( agent_name )
      unless @agents.key? agent_name
        raise UserError.new( JIJI::ERROR_NOT_FOUND, "agent not found. name=#{agent_name}")
      end
      @agents[agent_name].active
    end

    # レートを受け取ってエージェントに通知する。
    def next_rates( rates )
      @operator.next_rates( rates )
      @agents.each_pair {|n,a|
          a.output.time = rates.time
      }
      safe( conf.get( [:agent,:safe_level], 4) ){
        @agents.each_pair {|n,a|
          next unless a.active
          if @failsafe
            JIJI::Util.log_if_error( @logger ) {
              next unless a.active
              a.agent.next_rates( rates )
            }
          else
            JIJI::Util.log_if_error_and_throw( @logger ) {
              a.agent.next_rates( rates )
            }
          end
         }
      }
      # 取引結果の集計
      @trade_result_dao.next( operator, rates.time )
    end

    # 取引結果データを強制的にファイルに出力する。
    def flush( time )
      @trade_result_dao.flush( time )
      @operator.flush
    end

    attr :agent_registry, true
    attr :client, true
    attr :trade_result_dao, true
    attr :operator, true
    attr :conf, true
    attr :registry, true
  end

end