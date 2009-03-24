
require 'jiji/error'
require 'jiji/agent/agent'
require 'jiji/agent/util'
require 'jiji/util/file_lock'
require 'set'

module JIJI
  
  module Agent
    module Shared
      @@deleates = {}
      def self.const_missing(id)
        super unless @@deleates
        result = nil
        @@deleates.each_pair{|k,v|
          if v.const_defined?(id)
            result = v.const_get(id)
            break
          end
        }
        result ? result : super
      end
      def self.method_missing(name,*args, &block)
        super unless @@deleates
        target = nil
        @@deleates.each_pair{|k,v|
          if v.respond_to?(name)
            target = v
            break
          end
        }
        target ? target.send( name, *args, &block ) : super
      end
      def self._delegates
        @@deleates
      end
    end
  end
  
  #==エージェントレジストリ
  class AgentRegistry

    include JIJI::AgentUtil
    include Enumerable

    def initialize( agent_dir, shared_lib_dir )
      @agent_dir = agent_dir
      FileUtils.mkdir_p @agent_dir
      @shared_lib_dir = shared_lib_dir
      FileUtils.mkdir_p @shared_lib_dir

      @agents = {}
    end

    # エージェント名を列挙する
    def each( &block )
      checked = Set.new
      @agents.each() { |k,m|
        find_agent( k, m, checked ) {|name| block.call(name) }
      }
    end

    # エージェントを生成する
    def create(name, properties={})
      cl = get(name)
      safe( conf.get( [:agent,:safe_level], 4) ){
	      agent = cl.new
	      agent.properties = properties
	      agent
      }
    end

    #エージェントを取得する
    #name:: エージェント名( @ )
    def get(name)
      unless name =~ /([^@]+)@([^@]+)/
        raise UserError.new( JIJI::ERROR_NOT_FOUND,
          "agent class not found. name=#{name}")
      end
      m = @agents[$2]
      unless m
        raise UserError.new( JIJI::ERROR_NOT_FOUND,
          "agent class not found. name=#{name}")
      end

      path = $1.split("::")
      path.each {|step|
        unless m.const_defined? step
          raise UserError.new( JIJI::ERROR_NOT_FOUND,
            "agent class not found. name=#{name}")
        end
        m = m.const_get step
        unless m
          raise UserError.new( JIJI::ERROR_NOT_FOUND,
            "agent class not found. name=#{name}")
        end
        unless m.kind_of?(Module)
          raise UserError.new( JIJI::ERROR_NOT_FOUND,
            "agent class not found. name=#{name}")
        end
      }
      if m.kind_of?(Class) && m < JIJI::Agent
        m
      else
        raise UserError.new( JIJI::ERROR_NOT_FOUND,
          "agent class not found. name=#{name}")
      end
    end

    # エージェントのプロパティ一覧を取得する
    def get_property_infos(name)
      cl = get(name)
      return [] unless cl
      safe( conf.get( [:agent,:safe_level], 4) ){
        cl.new.property_infos
      }
    end

    # エージェントの説明を取得する
    def get_description(name)
      cl = get(name)
      return [] unless cl
      safe( conf.get( [:agent,:safe_level], 4) ){
        cl.new.description
      }
    end

    # ファイル名の一覧を得る。
    def files( type=:agent )
      lock(type) {
        Dir.glob( "#{dir(type)}/*.rb" ).map {|item|
          { "name"  =>File.basename(item),
            "update"=>File.mtime(item).to_i }
        }.sort_by {|item| item["name"]  }
      }
    end

    # エージェントファイルの本文を取得する。
    def get_file(file, type=:agent )
      lock(type) {
        file = "#{dir(type)}/#{file}"
        unless File.exist? file
          raise UserError.new( JIJI::ERROR_NOT_FOUND,
            "#{type} file not found. file_name=#{file}}")
        end
        IO.read(file)
      }
    end

    # エージェント置き場から、エージェントをロードする。
    def load_all
      lock(:shared_lib) {
        Dir.glob( "#{@shared_lib_dir}/*.rb" ) {|shared_lib_file|
          inner_load( shared_lib_file, :shared_lib )
        }
      }
      lock(:agent) {
        Dir.glob( "#{@agent_dir}/*.rb" ) {|agent_file|
          inner_load( agent_file, :agent )
        }
      }
    end

    # 特定のファイルをロードする。
    def load(file)
      file = "#{@agent_dir}/#{file}"
      unless File.exist? file
        raise UserError.new( JIJI::ERROR_NOT_FOUND,
          "agent file not found. file_name=#{file}}")
      end
      lock(:agent) { inner_load( file ) }
    end

    # ファイルを追加/更新する。
    def add_file( file_name, body, type=:agent )
      lock(type) {
        file = "#{dir(type)}/#{file_name}"
        File.open( file, "w" ) {|f|
          f.puts body
        }
        inner_load( file, type )
      }
    end

    # ファイルを破棄する
    def remove_file( file_name, type=:agent )
      lock(type) {
        file = "#{dir(type)}/#{file_name}"
        unless File.exist? file
          raise UserError.new( JIJI::ERROR_NOT_FOUND,
            "#{type} file not found. file_name=#{file_name}")
        end
        FileUtils.rm_rf file
        @agents.delete file_name if type==:agent
      }
    end

    attr :conf, true

  private

    # 種別に対応するディレクトリ名を得る。
    def dir( type )
      return type == :agent ? @agent_dir : @shared_lib_dir
    end

    def inner_load( file, type=:agent )
      error = nil
      body = IO.read(file).taint
      m = Module.new.taint
      if type == :agent
        @agents[ File.basename(file) ] = m
      else
        JIJI::Agent::Shared._delegates[ File.basename(file) ] = m
      end
      safe( conf.get( [:agent,:safe_level], 4) ){
        begin
          m.module_eval( body, file, 1 )
        rescue Exception => e
          # エラーになっても読み込みは継続。
          # 戻り値としてエラーの情報を返す
          error = e.to_s
        end
      }
      return error ? error : :success
    end

    def lock( type=:agent )
      DirLock.new( dir(type) ).writelock {
        yield if block_given?
      }
    end
    def find_agent( file, m, checked, &block )
      return if checked.include? m
      checked << m
      m.constants.each {|name|
        cl = m.const_get name
        begin 
          block.call( "#{get_name(cl.name)}@#{file}" ) if cl.kind_of?(Class) && cl < JIJI::Agent
        rescue Exception
        end
        find_agent( file, cl, checked, &block ) if cl.kind_of?(Module)
      }
    end
    def get_name( name )
      name.split("::", 2)[1]
    end
  end

end