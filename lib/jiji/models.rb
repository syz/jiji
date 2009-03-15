
require 'jiji/util/util'
require "jiji/dao/timed_data_dao"

module JIJI

  #==レートの集合
  class Rates < Hash

    include JIJI::Util::Model

    def initialize( pair_infos, list, time=Time.now )
      super()
      @pair_infos = pair_infos.inject({}){ |r,pair|
        code = JIJI::Util.convert_currency_pair_code(pair[0])
        r[code] = pair[1]
        r
      }
      @time = time
      list.each_pair { |k,info|
        self[k] = Rate.new( info.bid.to_f, info.ask.to_f,
          info.sell_swap.to_f, info.buy_swap.to_f, time)
      }
    end
    # 通貨ペアの情報(取引数量など)
    attr_reader :pair_infos
    # 現在時刻
    attr_reader :time
  end

  #==レート
  class Rate

    include JIJI::Util::Model
    include JIJI::Dao::TimedData

    def initialize( bid=nil, ask=nil, sell_swap=nil, buy_swap=nil, time=nil )
      @bid = bid
      @ask = ask
      @sell_swap = sell_swap
      @buy_swap = buy_swap
      @time = time
    end
    # 値を配列で取得する
    def values
      [bid,ask,sell_swap,buy_swap,time.to_i]
    end
    # 値を配列で設定する
    def values=(values)
      @bid = values[0].to_f
      @ask = values[1].to_f
      @sell_swap = values[2].to_f
      @buy_swap  = values[3].to_f
    end
    attr_reader :bid, :ask, :sell_swap, :buy_swap
  end

  #==一定期間のレートの集合
  class  PeriodicallyRates < Hash

    include JIJI::Util::Model

    def initialize( pair_infos, list=[] )
      super()
      @pair_infos = pair_infos
      list.each {|rates|
        self << rates
      }
    end
    def <<(rates)
      now = rates.time
      @start_time = now unless @start_time
      @end_time   = now
      rates.each_pair { |code,rate|
        self[code] = PeriodicallyRate.new unless key? code
        self[code] << rate
      }
    end
    def time
      @start_time
    end
    attr_reader :pair_infos
    attr :start_time, true
    attr :end_time, true
  end

  #==一定期間のレート
  #bid,ask,sell_swap,buy_swapは四本値(JIJI::PeriodicallyValue)で保持される。
  class PeriodicallyRate

    include JIJI::Util::Model
    include JIJI::Dao::TimedData

    def initialize( list=[] )
      @bid = PeriodicallyValue.new
      @ask = PeriodicallyValue.new
      @sell_swap = PeriodicallyValue.new
      @buy_swap  = PeriodicallyValue.new
      list.each { |item|
        self << item
      }
    end
    def <<( rate )
      @bid << rate.bid
      @ask << rate.ask
      @sell_swap << rate.sell_swap
      @buy_swap  << rate.buy_swap
      @start_time = rate.time unless @start_time
      @end_time = rate.time
    end
    # 値を配列で取得する
    def values
      bid.values + ask.values + sell_swap.values + buy_swap.values \
        + [@start_time.to_i, @end_time.to_i]
    end
    # 値を配列で設定する
    def values=(values)
      @bid.values = values[0..3]
      @ask.values = values[4..7]
      @sell_swap.values = values[8..11]
      @buy_swap.values = values[12..15]
      @start_time = Time.at(values[16].to_i)
      @end_time = Time.at(values[17].to_i)
    end
    def time
      @end_time
    end
    def time=(t)
      @end_time = t
    end
    attr_reader :bid, :ask, :sell_swap, :buy_swap
    attr :start_time, true
    attr :end_time, true
  end

  #==一定期間の値
  #始値、終値、高値、安値の四本値
  class PeriodicallyValue

    include JIJI::Util::Model

    def initialize( list=[] )
      list.each { |item|
        self << item
      }
    end
    def <<( value )
      @start = value if @start == nil
      @end = value
      @max = value if @max == nil || value > @max
      @min = value if @min == nil || value < @min
    end
    # 値を配列で取得する
    def values
      [@start, @end, @max, @min]
    end
    # 値を配列で設定する
    def values=(values)
      @start = values[0].to_f
      @end   = values[1].to_f
      @max   = values[2].to_f
      @min   = values[3].to_f
    end
    attr :start
    attr :end
    attr :max
    attr :min
  end
end