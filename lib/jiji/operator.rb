
require 'fileutils'
require 'delegate'
require 'jiji/util/util'
require 'jiji/single_click_client'
require 'jiji/util/util'
require 'jiji/dao/timed_data_dao'
require 'uuidtools'

module JIJI

  #==オペレーター
  class Operator

    #===コンストラクタ
    #*money*:: 保証金
    def initialize( trade_result_dao=nil, money=nil )
      @rate = nil
      @money = money
      @profit_or_loss = 0
      @fixed_profit_or_loss = 0
      @positions = {}
      @draw = 0
      @lose = 0
      @win = 0.0
      @trade_result_dao = trade_result_dao
    end

    #===レートを更新する。
    def next_rates( rate )
      @rate = rate
      result = @positions.inject({:total=>0.0,:profit=>0}) {|r,e|
        p = e[1]
        p.next(rate)
        r[:total] += p.price if p.state == Position::STATE_START
        r[:profit] += p.profit_or_loss
        r
      }
      @profit_or_loss = result[:profit] + @fixed_profit_or_loss
      if @money && (( @money + result[:profit] ) / result[:total]) <= 0.007
        raise "loss cut"
      end
      @trade_result_dao.next( self, rate.time ) if @trade_result_dao
    end

    #===購入する
    #count:: 購入する数量
    #pair:: 通貨ペア(:EURJPYなど)
    #trader:: 取引実行者識別用の名前
    #return:: Position
    def buy(count, pair=:EURJPY, trader="")
      rate = @rate[pair]
      unit = @rate.pair_infos[pair].trade_unit
      p = Position.new( UUID.random_create().to_s, Position::BUY, count,
        unit, @rate.time, rate.ask, pair, trader, self )
      p.next( @rate )
      @profit_or_loss += p.profit_or_loss
      @positions[p.position_id] = p
      @trade_result_dao.save( p ) if @trade_result_dao
      return p
    end

    #===売却する
    #count:: 売却する数量
    #pair:: 通貨ペア(:EURJPYなど)
    #trader:: 取引実行者識別用の名前
    #return:: Position
    def sell(count, pair=:EURJPY, trader="")
      rate = @rate[pair]
      unit = @rate.pair_infos[pair].trade_unit
      p = Position.new( UUID.random_create().to_s, Position::SELL, count,
        unit, @rate.time, rate.bid, pair, trader, self )
      p.next( @rate )
      @profit_or_loss += p.profit_or_loss
      @positions[p.position_id] = p
      @trade_result_dao.save( p ) if @trade_result_dao
      return p
    end

    # 取引を確定する
    def commit(position)
      position._commit
      @trade_result_dao.save( position ) if @trade_result_dao
      @positions.delete position.position_id

      @fixed_profit_or_loss += position.profit_or_loss
      if position.profit_or_loss == 0
        @draw+=1
      elsif position.profit_or_loss < 0
        @lose+=1
      else
        @win+=1
      end
    end

    # 勝率
    def win_rate
      win > 0 ? win / (win+lose+draw) : 0.0
    end

    # 未約定のポジションデータを"ロスト"としてマークする。
    def stop
      @positions.each_pair {|k, v|
        v.lost
        @trade_result_dao.save( v ) if @trade_result_dao
      }
    end

    # すべてのポジションデータを保存する。
    def flush
      @positions.each_pair {|k, v|
        @trade_result_dao.save( v ) if @trade_result_dao
      }
    end

    #現在の損益
    attr_reader :profit_or_loss
    #現在の確定済み損益
    attr_reader :fixed_profit_or_loss
    #建て玉
    attr :positions

    # 勝ち数
    attr_reader :win
    # 負け数
    attr_reader :lose
    # 引き分け
    attr_reader :draw

    attr :conf, true
  end



  #==ポジション
  class Position

    #売り/買い区分
    SELL = 0
    BUY  = 1

    #状態:注文中
    STATE_WAITING = 0
    #状態:新規
    STATE_START = 1
    #状態:決済注文中
    STATE_FIX_WAITING = 2
    #状態:決済済み
    STATE_FIXED = 3
    #状態:約定前にシステムが再起動された
    STATE_LOST = 4

    #===コンストラクタ
    #
    #*sell_or_buy*:: 売りor買い
    #*count*:: 数量
    #*unit*:: 取引単位
    #*date*:: 取引日時
    #*rate*:: レート
    #*pair*:: 通貨ペア
    #*trader*:: 取引実行者
    #*operator*:: operator
    #*open_interest_no*:: 建玉番号
    #*order_no*:: 注文番号
    def initialize( position_id, sell_or_buy, count, unit, date, rate, pair,
      trader, operator, open_interest_no="", order_no="" )
      @position_id = position_id
      @sell_or_buy = sell_or_buy
      @count = count
      @unit = unit
      @price = (count*unit*rate).to_i
      @date = date
      @profit_or_loss = 0
      @state =STATE_START
      @rate = rate
      @pair = pair
      @trader = trader

      @open_interest_no = open_interest_no
      @order_no = order_no

      @operator = operator
      @info = {}
      @swap = 0
      @swap_time = Time.local( date.year, \
        date.month, date.day, operator.conf.get([:swap_time], 5 ))
      @swap_time += 60*60*24 if date > @swap_time
    end

    def _commit
      raise "illegal state" if @state != STATE_START
      @state = STATE_FIXED
      @fix_date = @current_date
      @fix_rate = @current_rate
    end

    def lost
      @state = STATE_LOST
    end

    #===現在価格を更新
    def next(rates)
      return if @state == STATE_FIXED
      rate = rates[@pair]
      @current_rate = @sell_or_buy == BUY ? rate.bid : rate.ask
      @current_price = (@count * @unit * @current_rate).to_i

      # swap
      if @swap_time <= rates.time
        @swap += @sell_or_buy == BUY ? rate.buy_swap : rate.sell_swap
        @swap_time += 60*60*24
      end

      @profit_or_loss = @sell_or_buy == BUY \
          ? @current_price - @price + @swap\
          : @price - @current_price + @swap

      @current_date = rates.time
    end

    def [](key)
      @info[key]
    end
    def []=(key, value)
      @info[key] = value
    end

    def values
      {
        :position_id => position_id,
        :open_interest_no=> open_interest_no,
        :sell_or_buy =>  sell_or_buy == JIJI::Position::SELL ? :sell : :buy,
        :state => state,
        :date => date.to_i,
        :fix_date => fix_date.to_i,
        :count => count ,
        :price => price,
        :profit_or_loss => profit_or_loss.to_i,
        :rate => rate,
        :fix_rate => fix_rate,
        :swap=> swap,
        :pair => pair,
        :trader => trader
      }
    end

    # クライアント
    attr :operator
    # 建玉番号
    attr :open_interest_no, true
    # 注文番号
    attr :order_no, true

    # 一意な識別子
    attr_reader :position_id
    # 売りか買いか?
    attr_reader :sell_or_buy
    # 状態
    attr_reader :state

    # 購入日時
    attr_reader :date
    # 決済日時
    attr_reader :fix_date
    # 取引数量
    attr_reader :count
    # 取得金額
    attr_reader :price
    # 現在価値
    attr_reader :current_price
    # 現在の損益
    attr_reader :profit_or_loss
    # 購入時のレート
    attr_reader :rate
    # 決済時のレート
    attr_reader :fix_rate
    # 決済時のレート
    attr_reader :swap
    # 通貨ペア
    attr_reader :pair
    # 取引実行者
    attr_reader :trader
  end

  #==リアル取引用オペレーター
  class RmtOperator < Operator

    #===コンストラクタ
    #*client*:: クライアント
    #*logger*:: ロガー
    #*money*:: 保証金
    def initialize( client, logger, trade_result_dao, trade_enable=true, money=nil )
      super(trade_result_dao,money)
      @client = client
      @logger = logger
      @trade_enable = trade_enable
    end

    #===購入する
    #*count*:: 購入する数量
    #*return*:: Position
    def buy(count, pair=:EURJPY, trader="")
      open_interest_no = nil
      order_no = nil
      if @trade_enable
        JIJI::Util.log_if_error_and_throw( @logger ) {
	        rate = @rate[pair]
		      # 成り行きで買い
		      result = @client.request{ |fx|
		        fx.order( JIJI::Util.convert_currency_pair_code_r(pair),
		          ClickClient::FX::BUY, count, options={:slippage_base_rate=>rate.bid} )
	        }
	        open_interest_no = result.open_interest_no
	        order_no = result.order_no
	      }
	    end
      p = super(count, pair, trader)
      p.open_interest_no = open_interest_no
      p.order_no = order_no
      p
    end

    #===売却する
    #*count*:: 売却する数量
    #*return*:: Position
    def sell(count, pair=:EURJPY, trader="")
      open_interest_no = nil
      order_no = nil
      if @trade_enable
	      JIJI::Util.log_if_error_and_throw( @logger ) {
	        rate = @rate[pair]
	        # 成り行きで売り
		      result = @client.request {|fx|
		        fx.order( JIJI::Util.convert_currency_pair_code_r(pair),
		          ClickClient::FX::SELL, count, options={:slippage_base_rate=>rate.ask} )
	        }
	        open_interest_no = result.open_interest_no
	        order_no = result.order_no
	      }
	    end
      p = super(count, pair, trader)
      p.open_interest_no = open_interest_no
      p.order_no = order_no
      p
    end

    # 取引を確定する
    def commit(position)
      if @trade_enable
	      JIJI::Util.log_if_error_and_throw( @logger ) {
	        @client.request {|fx|
	          fx.settle( position.open_interest_no, position.count )
	        }
	      }
	    end
      super(position)
    end

    attr :trade_enable, true
  end

  # 各エージェントに設定されるオペレータ。
  # 取引者としてエージェント名を指定して売り買いを行なう。
  # また、建玉を独自に保持する。(エージェント間で共有されない)
  # 売/買ロジック自体ははオペレータに委譲する。
  class AgentOperator
    def initialize( operator, agent_name )
      @operator = operator
      @name = agent_name
      @positions = {}.taint
    end

    #===購入する
    #count:: 購入する数量
    #pair:: 通貨ペア
    #return:: ポジション
    def buy(count, pair=:EURJPY)
      p = @operator.buy( count, pair, @name )
      @positions[p.position_id] = p
      return p
    end

    #===売却する
    #count:: 売却する数量
    #pair:: 通貨ペア
    #return:: ポジション
    def sell(count, pair=:EURJPY)
      p = @operator.sell( count, pair, @name )
      @positions[p.position_id] = p
      return p
    end

    # 取引を確定する
    def commit(position)
      @operator.commit(position)
      @positions.delete position.position_id
    end
   
    #建て玉
    attr_reader :positions
    
  end

end

