module JIJI
  module Service
    class OutputService

      # 指定範囲の出力データを取得する。
      def list_datas( process_id, names, scale, start_time, end_time )
        p = process_manager.get( process_id )
        list = {}
        names.each {|n|
	        buff = []
          outputs = p.agent_manager.get(n[0]).output
	        outputs.get(n[1]).each( scale,
            Time.at(start_time), Time.at(end_time) ) {|data|
	          buff << data
	        }
          list[n[0]] = {} if !list[n[0]]
          list[n[0]][n[1]] = buff
        }
        return list
      end

      # プロセスの出力一覧を取得する
      def list_outputs( process_id )
        p = process_manager.get( process_id )
        return p.agent_manager.inject({}) {|buff,item|
          buff[item[0]] = item[1].output.inject({}) {|r,v|
            r[v[0]] = v[1].options
            r
          }
          buff
        }
      end

      # アウトプットのプロパティを設定
      def set_properties( process_id, name, properties )
        p = process_manager.get( process_id )
        outputs = p.agent_manager.get(name[0]).output
        outputs.get(name[1]).set_properties( properties )
        return :success
      end

      # プロセスのログを取得する
      def get_log( process_id )
        process_manager.get( process_id ) # プロセスの存在確認
        file = "#{@process_dir}/#{process_id}/log.txt" # TODO 古いものも連結するか? サイズが大きくなってしまうので微妙。
        if ( File.exist?( file ) ) 
          return IO.read( file )
        else
          return ""
        end
      end
      
      attr :process_dir, true
      attr :process_manager, true
	  end

  end
end