
require 'jiji/util/file_lock'
require "jiji/models"
require 'jiji/util/util'
require 'jiji/operator'
require 'jiji/single_click_client'
require 'jiji/output'

module JIJI
  
  # エージェントを示すマーカーモジュール
  module Agent
    # プロパティ設定後に呼び出される。
    def init( )
    end    
    # 次のレートを受け取る
    def next_rates( rates )
    end
    # 設定可能なプロパティの一覧を返す
    def property_infos
      []
    end
    # 設定されたプロパティを取得する
    def properties
      @properties
    end    
    # プロパティを設定する
    def properties=( properties )
      @properties = properties
      properties.each_pair {|k,v|
        instance_variable_set("@#{k}", v)
      }
    end
    
    # エージェントの説明を返す
    def description
      ""
    end
    
    # オペレータ
    attr :operator, true
    # エラーロガー
    attr :logger, true
    # データの出力先
    attr :output, true
        
    # エージェントのプロパティ
    class Property
      include JIJI::Util::Model
      include JIJI::Util::JsonSupport
      def initialize( id, name, default_value=nil, type=:string )
        @id = id
        @name = name
        @default = default_value
        @type = type
      end
      attr :id, true
      attr :name, true    # UIでの表示用の名前
      attr :default, true # 初期値
      attr :type, true
    end    
  
  end
  
  
  # 一定期間ごとに通知を受け取るエージェントの基底クラス。
  class PeriodicallyAgent
    include JIJI::Agent
    def initialize( period=10 )
      @period = period
      @start = nil
      @rates = nil
    end
    def next_rates( rates )
      @rates = PeriodicallyRates.new( rates.pair_infos ) unless @rates
      now = rates.time
      @start = now unless @start
      @rates << rates
      if ( now - @start ) > @period*60
        next_period_rates( @rates )
        @rates = PeriodicallyRates.new( rates.pair_infos )
        @rates.start_time = now
        @start = now
      end
    end
    def property_infos
      super() + [Property.new(:period, "レートの通知を受け取る間隔(分)", 10, :number)]
    end
    def next_period_rates( rates )
    end
  end
  
end