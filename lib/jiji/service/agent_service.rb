
require 'jiji/error'
require 'jiji/agent/agent'
require 'jiji/agent/agent_manager'
require 'jiji/agent/agent_registry'
require 'jiji/agent/permitter'
require 'jiji/agent/util'


module JIJI
  module Service
    class AgentService

      include JIJI::AgentUtil

      # ファイルの一覧を取得する
      def list_files( type=:agent )
        @agent_registry.files( type.to_sym )
      end

      # ファイルの内容を取得する
      def get_file( file_name, type=:agent )
        check_filename( file_name )
        @agent_registry.get_file( file_name, type.to_sym )
      end


      # エージェントの一覧を取得する
      def list_agent_class
        @agent_registry.inject([]) {|list,name|
          next unless name =~ /([^@]+)@([^@]+)/
          list << {
            "class_name"=>$1,
            "file_name"=>$2,
            "properties"=>@agent_registry.get_property_infos(name),
            "description"=>@agent_registry.get_description(name)
          }
          list
        }
      end

      # ファイルを追加/更新する
      def put_file( file_name, body, type=:agent )
        check_filename( file_name )
        @agent_registry.add_file( file_name, body, type.to_sym )
      end

      # ファイルを削除する
      def delete_files( file_names, type=:agent )
        file_names.each {|fn|
          check_filename( fn )
        }
        file_names.each {|fn|
          @agent_registry.remove_file( fn, type.to_sym )
        }
        :success
      end


      # プロセスに登録されているエージェントの一覧を得る
      def list_agent( process_id )
        p = process_manager.get( process_id )
        safe(4) {
          p.agent_manager.collect.map! {|entry|
            props = entry[1].agent.properties
            {
              "name"=>entry[0],
              "properties"=>entry[1].agent.property_infos.map! {|info|
                prop = props.find() {|e| e[0] == info.id.to_s }
                { "id"=>info.id.to_s, "info"=>info, "value"=> prop ? prop[1] : nil }
              },
              "description"=>entry[1].agent.description,
              "active"=>entry[1].active
            }
          }
        }
      end

      # プロセスにエージェントを追加する
      def add_agent( process_id, name, class_name, properties )
        p = process_manager.get( process_id )
        agent = agent_registry.create( class_name, properties )
        p.agent_manager.add( name, agent )
        :success
      end

      # プロセスのエージェントを削除する
      def remove_agent( process_id, name )
        p = process_manager.get( process_id )
        p.agent_manager.remove( name )
        :success
      end

#      # エージェントのプロパティを更新する
#      def set_agent_properties( process_id, name, properties )
#        p = process_manager.get( process_id )
#        p.agent_manager.get( name ).properties = properties
#      end

      # プロセスのエージェントを一時的に無効化する
      def off( process_id, name )
        p = process_manager.get( process_id )
        p.agent_manager.off( name )
        :success
      end
      # プロセスのエージェントの無効化を解除する
      def on( process_id, name )
        p = process_manager.get( process_id )
        p.agent_manager.on( name )
        :success
      end
      # プロセスのエージェントの無効化状態を取得する
      def on?( process_id, name )
        p = process_manager.get( process_id )
        p.agent_manager.on?( name )
      end
      attr :agent_registry, true
      attr :process_manager, true

    private
      def check_filename( file_name )
        unless file_name =~ VALID_FILE_NAME
          raise JIJI::UserError.new( ERROR_ILLEGAL_NAME, "illegal file name. name=#{file_name}" )
        end
      end
      VALID_FILE_NAME = /^[A-Za-z0-9_\*\+\-\#\"\'\!\~\(\)\[\]\?\.]+\.rb$/

    end

  end
end