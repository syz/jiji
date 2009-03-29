
require 'rubygems'
require "highline"
require 'jiji/server'
require 'jiji/util/json_rpc_requestor'

module JIJI

  # コマンドラインツール
  class Command

    # 設定ファイル置き場
    JIJI_DIR_NAME = "~/.jiji"


    # サービスを開始
    def start
      begin
        puts "jiji started."
        s = JIJI::FxServer.new( data_dir )
        s.start
      rescue Exception
        puts "[ERROR] start failed.(#{$!.to_s})"
        return
      end
    end

    # サービスを停止
    def stop
      begin
        host = ARGV[1] || "localhost"
        conf = JIJI::Registry.new(data_dir)[:conf]
        port = conf.get([:server,:port], 7000).to_i
        service = JSONBroker:: JsonRpcRequestor.new( "system", "http://#{host}:#{port}" )
        service.shutdown
        sleep 10 # 停止完了を待つ。
        puts "jiji stopped."
      rescue Exception
        puts "[ERROR] stop failed.(#{$!.to_s})"
        return
      end

    end

    # 初期化
    def setting
      h = HighLine.new
      user = h.ask("> Please input a user name of CLICK Securities DEMO Trade.")
      pass = h.ask("> Please input a password of CLICK Securities DEMO Trade."){|q| q.echo = '*' }
      dir  = h.ask("> Please input a data directory of jiji. (default: #{JIJI_DIR_NAME} )")
      dir = !dir || dir.empty? ? JIJI_DIR_NAME : dir

      port = h.ask('> Please input a server port. (default: 7000 )')
      port = !port || port.empty? ? "7000" : port
      unless port =~ /\d+/
        puts "[ERROR] setting failed.( illegal port number. port=#{port} )"
        return
      end

      # ディレクトリ作成
      begin
        puts ""
        ex_dir = File.expand_path(JIJI_DIR_NAME)
        mkdir ex_dir
        open( "#{ex_dir}/base", "w" ) {|f|
          f << dir
        }
        puts "create. #{ex_dir}/base"

        # ベースディレクトリの作成
        dir = File.expand_path(dir)
        mkdir(dir) if ( dir != ex_dir )
        mkdir("#{dir}/conf")

        # 設定ファイル
        open( "#{dir}/conf/configuration.yaml", "w" ) {|f|
          f << <<-DATA
---
server:
 port: #{port}

securities:
  account:
    user:     "#{user}"
    password: "#{pass}"
DATA
        }
        FileUtils.chmod(0600, "#{dir}/conf/configuration.yaml")

        # サンプルエージェント
        ["agents","shared_lib"].each {|d|
          mkdir("#{dir}/#{d}")
          FileUtils.copy( Dir.glob(File.expand_path("#{__FILE__}/../../../base/#{d}/*")), "#{dir}/#{d}" )
        }
      rescue Exception
        puts "[ERROR] setting failed.(#{$!.to_s})"
        return
      end

      puts "Setting was completed!"
    end


    def run( args )
      case  args[0]
        when "start"; start
        when "stop";  stop
        when "setting"; setting
        when "restart"
          stop
          start
        else
          name = File.basename( File.expand_path( $0 ))
          puts "usage : #{name} ( setting | start | stop | restart )"
      end
    end

  private
    # データディレクトリを得る
    def data_dir
      base = "#{File.expand_path(JIJI_DIR_NAME)}/base"
      unless File.exist?( base  )
        raise "'#{base}' is not found. You need to run 'jiji setting'."
      end
      return File.expand_path(IO.read( base  ))
    end
    # ディレクトリを作る。
    def mkdir( path )
      FileUtils.mkdir_p path
      FileUtils.chmod(0755, path)
      puts "create. #{path}"
    end

  end
end