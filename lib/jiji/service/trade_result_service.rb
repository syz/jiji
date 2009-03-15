module JIJI
  module Service
    class TradeResultService
      
      # 指定範囲のトレード結果を取得する。
      def list( process_id, scale, start_time, end_time )
        p = process_manager.get( process_id )
        dao = p.agent_manager.trade_result_dao
        result = dao.list_positions( scale, start_time ? Time.at(start_time) : nil, end_time ? Time.at(end_time) : nil )
        # 現在進行中の建て玉はoperatorから取得する
        op = p.agent_manager.operator
        return result.map {|e|
          op && op.positions.key?(e[0]) ? op.positions[e[0]].values : e[1] 
        }
      end
      
      # 指定範囲の損益を取得する。
      def list_profit_or_loss( process_id, scale, start_time, end_time )
        p = process_manager.get( process_id )
        dao = p.agent_manager.trade_result_dao
        buff = []
        dao.each( scale, start_time ? Time.at(start_time) : nil, end_time ? Time.at(end_time) : nil ) {|data|
          buff << data
        }
        return buff
      end
      
      attr :process_manager, true
	  end
    
  end
end