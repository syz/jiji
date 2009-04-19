
require 'jiji/util/util'
require "jiji/dao/timed_data_dao"
require 'yaml'
require 'jiji/util/fix_yaml_bug'
require 'jiji/util/file_lock'
require 'fileutils'

module JIJI

  # データの出力先
  class Output

    include Enumerable

    def initialize( agent_name, dir, scales=[] )
      @dir = "#{dir}/#{JIJI::Util.encode(agent_name).gsub(/\//, "_")}" # 「ベースディレクトリ/エージェント名/出力名」に保存する。
      FileUtils.mkdir_p @dir

      @outs = {}
      @scales = scales

      # 既存データの読み込み
      DirLock.new( @dir ).writelock {
        Dir.glob( "#{@dir}/*" ) {|d|
          next unless File.directory? d
          next unless File.exist? "#{d}/meta.yaml"
          props = YAML.load_file "#{d}/meta.yaml"
          @outs[props[:name]] =
            create_output( d, props[:name], props[:type].to_sym, props )
        }
      }
    end

    # 名前に対応する出力先を得る。
    # 対応する出力先がなければ新規に作成。
    #
    #name:: 名前(UIでの表示名)
    #type:: 種別。:event,:graphのいずれかが指定可能
    #option:: 補足情報。以下が指定可能
    # -*グラフの場合*
    # --[:column_count] .. グラフのカラム数を整数値で指定する。(*必須*)
    # --「:graph_type」 .. グラフの種類を指定する。以下の値が指定可能。
    # ---"rate" ..  レート情報に重ねて表示(移動平均線やボリンジャーバンド向け)。グラフは、ローソク足描画領域に描画される。
    # ---"zero_base" ..  0を中心線とした線グラフ(RCIやMACD向け)。グラフは、グラフ描画領域に描画される。
    # ---"line" ..  線グラフとして描画する。(デフォルト)。グラフは、グラフ描画領域に描画される。
    # --「:colors」 .. グラフの色を「#FFFFFF」形式の文字列の配列で指定する。指定を省略した場合「0x557777」で描画される。
    #return:: 出力先
    def get( name, type=:graph, options={} )
      raise "illegal Name. name=#{name}" if name =~ /[\x00-\x1F\x7F\\\/\r\n\t]/
      return @outs[name] if @outs.key? name
      DirLock.new( @dir ).writelock {
        sub_dir = "#{@dir}/#{JIJI::Util.encode(name).gsub(/\//, "_")}"
        FileUtils.mkdir_p sub_dir
        options[:type] = type.to_s
        options[:name] = name
        @outs[name] = create_output( sub_dir, name, type, options )
        @outs[name].time = time
        @outs[name].save
      }
      @outs[name]
    end

    # 出力先を列挙する
    def each( &block )
      @outs.each( &block )
    end

    # 現在時刻を設定する
    def time=(time)
      @time = time
      @outs.each_pair {|k,v|
        v.time = time
      }
    end
    # 現在時刻
    attr_reader :time
    # スケール
    attr :scales, true
  private
    # 出力先を作る
    def create_output( sub_dir, name, type, options )
      case type
        when :event
          EventOut.new( sub_dir, name, options )
        when :graph
          GraphOut.new( sub_dir, name, options, @scales )
        else
          raise "unkown output type."
      end
    end
  end

  # 出力先の基底クラス
  class BaseOut

    include Enumerable

    # コンストラクタ
    def initialize( dir, name, options )
      @dir = dir
      @dao = JIJI::Dao::TimedDataDao.new( dir, aggregators )
      @options = options
    end

    # データを読み込む
    def each( scale=:raw, start_date=nil, end_date=nil, &block )
      @dao.each_data( scale, start_date, end_date ) { |row, time|
        yield row
      }
    end

    #プロパティを設定する。
    #props:: プロパティ
    def set_properties( props )
      props.each_pair {|k,v|
        @options[k.to_sym] = v
      }
      save
    end

    #設定値をファイルに出力
    def save
      FileLock.new("#{@dir}/meta.yaml" ).writelock { |f|
        f.write( YAML.dump(@options) )
      }
    end

    # 補足情報
    attr_reader :options
    # 現在時刻
    attr :time, true

  end

  # イベントデータの出力先
  class EventOut < BaseOut
    # ログを書き込む
    def put( type, message )
      @dao << JIJI::Dao::BasicTimedData.new(
        [type.to_s, message, @time.to_i.to_s], @time)
    end
    def aggregators
      [JIJI::Dao::RawAggregator.new]
    end
  end

  # グラフデータの出力先
  class GraphOut < BaseOut
    # コンストラクタ
    def initialize( dir, name, options, scales=[] )
      @scales = scales
      super( dir, name, options )
    end
    # ログを書き込む
    def put( *numbers )
      @dao << JIJI::Dao::BasicTimedData.new( numbers << @time.to_i, @time)
    end
    def aggregators
      list = @scales.map{|s| JIJI::Dao::AvgAggregator.new s}
      list << JIJI::Dao::RawAggregator.new
    end
  end

end