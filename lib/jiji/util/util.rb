
require 'kconv'
require 'jiji/error'

module JIJI
  
  module Util
  
  module_function
    # 通貨ペアコードをシンボルに変換する
    def convert_currency_pair_code(code)
      case code
        when ClickClient::FX::USDJPY
          return :USDJPY
        when ClickClient::FX::EURJPY
          return :EURJPY
        when ClickClient::FX::GBPJPY
          return :GBPJPY
        when ClickClient::FX::AUDJPY
          return :AUDJPY
        when ClickClient::FX::NZDJPY
          return :NZDJPY
        when ClickClient::FX::CADJPY
          return :CADJPY
        when ClickClient::FX::CHFJPY
          return :CHFJPY
        when ClickClient::FX::ZARJPY
          return :ZARJPY
        when ClickClient::FX::EURUSD
          return :EURUSD
        when ClickClient::FX::GBPUSD
          return :GBPUSD
        when ClickClient::FX::AUDUSD
          return :AUDUSD
        when ClickClient::FX::EURCHF
          return :EURCHF
        when ClickClient::FX::GBPCHF
          return :GBPCHF
        when ClickClient::FX::USDCHF
          return :USDCHF
      end
    end
    
    # シンボルを通貨ペアコードに変換する
    def convert_currency_pair_code_r(code)
      case code
        when :USDJPY
          return ClickClient::FX::USDJPY
        when :EURJPY
          return ClickClient::FX::EURJPY
        when :GBPJPY
          return ClickClient::FX::GBPJPY
        when :AUDJPY
          return ClickClient::FX::AUDJPY
        when :NZDJPY
          return ClickClient::FX::NZDJPY
        when :CADJPY
          return ClickClient::FX::CADJPY
        when :CHFJPY
          return ClickClient::FX::CHFJPY
        when :ZARJPY
          return ClickClient::FX::ZARJPY
        when :EURUSD
          return ClickClient::FX::EURUSD
        when :GBPUSD
          return ClickClient::FX::GBPUSD
        when :AUDUSD
          return ClickClient::FX::AUDUSD
        when :EURCHF
          return ClickClient::FX::EURCHF
        when :GBPCHF
          return ClickClient::FX::GBPCHF
        when :USDCHF
          return ClickClient::FX::USDCHF
      end
    end    
    
    #ブロック内で例外が発生したらログに出力する。
    #発生した例外は内部で握る。
    def log_if_error( logger ) 
      begin
        return yield if block_given?
      rescue Exception
        logger.error($!)
      end
    end
    #ブロック内で例外が発生したらログに出力する。
    #ログ出力後、例外を再スローする。
    def log_if_error_and_throw( logger ) 
      begin
        return yield if block_given?
      rescue Exception
        logger.error($!)
        throw $!
      end
    end    

    # 文字列をbase64でエンコードする
    def encode( str ) 
      [str].pack("m").gsub(/\//, "_").gsub(/\n/, "")
    end
    # base64でエンコードした文字列をデコードする
    def decode( str )
      str.gsub(/_/, "/").unpack('m')
    end
    
    # モデルオブジェクトの基底モジュール
    module Model
      
      # オブジェクト比較メソッド
      def ==(other)
        _eql?(other) { |a,b| a == b }
      end
      def ===(other)
        _eql?(other) { |a,b| a === b }
      end
      def eql?(other)
        _eql?(other) { |a,b| a.eql? b }
      end
      def hash
        hash = 0
        values.each {|v|
          hash = v.hash + 31 * hash
        }
        return hash
      end
    protected
      def values
        values = []
        values << self.class
        instance_variables.each { |name|
          values << instance_variable_get(name) 
        }
        return values
      end
    private
      def _eql?(other, &block)
        return false if other == nil
        return true if self.equal? other
        return false unless other.kind_of?(JIJI::Util::Model)
        a = values
        b = other.values
        return false if a.length != b.length
        a.length.times{|i|
          return false unless block.call( a[i], b[i] )
        }
        return true
      end
    end
    
    module JsonSupport   
      def to_json
        buff = "{"
        instance_variables.each { |name|
          buff << "#{name[1..-1].to_json}:#{instance_variable_get(name).to_json},"
        }
        buff.chop!
        buff << "}"
      end
    end
    
      
    # 期間を示す文字列を解析する
    def self.parse_scale( scale )
      return nil if  scale.to_s == "raw"
      unless scale.to_s =~ /(\d+)([smhd])/
        raise JIJI::UserError.new( JIJI::ERROR_ALREADY_EXIST, "illegal scale. scale=#{scale}") 
      end
      return case $2
        when "s"; $1.to_i
        when "m"; $1.to_i * 60
        when "h"; $1.to_i * 60 * 60
        when "d"; $1.to_i * 60 * 60 * 24
      end
    end
          
  
  end
end