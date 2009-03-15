
// ネームスペース
namespace( "fx.ui.pages" )

// 結果画面
fx.ui.pages.ResultPage = function() {

  this.elementPrefix = null;
  this.elementId = null; // @Inject
  this.processServiceStub = null; //@Inject

  // 現在表示中のプロセスID // toで画面遷移したタイミングで設定される。
  this.currentProcessId = null;

  this.submenu = null;
  this.dialog = null; // @Inject
  this.topicPath = null; // @Inject
}
fx.ui.pages.ResultPage.prototype = {

  /**
   * ページを初期化する。
   * ページ作成時に一度だけ呼び出すこと。
   */
  initialize: function(  ) {
    this.submenu = new util.MenuBar( "submenu",  "submenu", "submenu", this.pageManager );
    var self = this;
    this.submenu.initialize( null, function() {
      var m = this.id.match( /submenu\_(.*)/ );
      if ( m ) {
        self.submenu.to( m[1], {id:self.currentProcessId} );
      }
    } );
  },
  /**
   * このページから画面を移動する際に呼び出される。
   * 戻り値としてfalseを返すと遷移をキャンセルする。
   */
  from : function(toId) {
    // ページを非表示
    document.getElementById(this.elementId).style.display = "none";
    this.topicPath.set( "" );
    return true;
  },
  /**
   * このページに画面を移動すると呼び出される。
   */
  to : function( fromId, param ) {

    this.currentProcessId = param["id"];

    // チャートの初期化準備
    var swf = util.getSwf( "chart" );
    var date = this.currentProcessId == "rmt" ? null : param.end ;
    if ( fromId != "result" ) {
      // チャートが未ロードの場合
      // チャートのロード完了コールバックを受け取ってから初期化。
      var self = this;
      var global = function() { return this; }();
      global.onChartLoaded = function() {
        swf.initializeChart( self.currentProcessId, null, null, date );
        delete global.onChartLoaded; // 登録した関数は消しておく。
      }
    } else {
      // すでにロードされている場合、APIだけ呼び出す
      swf.initializeChart( this.currentProcessId, null, null, date );
    }

    // ページを表示
    document.getElementById(this.elementId).style.display = "block";

    // 初期化
    var msg = document.getElementById("bt-create_msg");
    msg.innerHTML = "";
    msg.style.display = "none";

    this.submenu.to( "trade", param );

    if ( param["id"] == "rmt"  ) {
      this.topicPath.set( "リアルトレード:状況を見る" );
    } else {
      this.topicPath.set( "バックテスト:結果を見る:" + param["name"] );
    }
  }
}

// ログ画面
fx.ui.pages.LogResultPage = function() {
  this.elementId = null; // @Inject
  this.outputServiceStub = null; //@Inject

  var self = this;
  this.updateButton = new util.Button("subpage-log__update", "update", function() {
    self.update();
  });
  this.updateButton.setEnable( true );
}
fx.ui.pages.LogResultPage.prototype = {
  /**
   * このページから画面を移動する際に呼び出される。
   * 戻り値としてfalseを返すと遷移をキャンセルする。
   */
  from : function(toId) {
    // ページを非表示
    document.getElementById(this.elementId).style.display = "none";
    return true;
  },
  /**
   * このページに画面を移動すると呼び出される。
   */
  to : function( fromId, param ) {
    // ページを表示
    document.getElementById(this.elementId).style.display = "block";
    this.currentProcessId = param.id;
    this.update();
  },
  update: function() {
    var logEl = document.getElementById( "subpage-log_log" );
    logEl.innerHTML= fx.template.Templates.common.loading;
    this.outputServiceStub.get_log( this.currentProcessId, function( log ) {
      logEl.innerHTML = "<pre style='line-height: 110%;'>" + log + "</pre>";
    }, function(){}  ); // TODO
  }
}

//トレード結果画面
fx.ui.pages.TradeResultPage = function() {
  this.elementId = null; // @Inject
  this.tradeResultServiceStub = null; //@Inject
  this.dialog = null; // @Inject
  var self = this;
  this.tradeListTable = new fx.ui.TradeListTable( "subpage-trade__list" );
  this.tradeListTable.initialize();
  this.agentResultListTable = new fx.ui.AgentResultListTable( "subpage-trade__agent-list" );
  this.agentResultListTable.initialize();
  this.updateButton = new util.Button("subpage-trade__update", "update", function() {
    self.update();
  });
  this.updateButton.setEnable( true );
}
fx.ui.pages.TradeResultPage.prototype = {
  /**
   * このページから画面を移動する際に呼び出される。
   * 戻り値としてfalseを返すと遷移をキャンセルする。
   */
  from : function(toId) {
    // ページを非表示
    document.getElementById(this.elementId).style.display = "none";
    return true;
  },
  /**
   * このページに画面を移動すると呼び出される。
   */
  to : function( fromId, param ) {

    this.currentProcessId = param.id;
    this.start = param.start;
    this.end = param.end;

    // ページを表示
    document.getElementById(this.elementId).style.display = "block";

    if ( param.id == "rmt" ) {
      document.getElementById("subpage-trade__range").style.display = "block";
    } else {
      document.getElementById("subpage-trade__range").style.display = "none";
    }

    this.update();
  },
  update: function() {
    var summaryEl = document.getElementById( "subpage-trade_summary" );

    // 一覧対象の日時
    var startDate = null;
    var endDate = null;
    if ( this.currentProcessId == "rmt" ) {

      // フィールドに値が設定されていればその値を使う。
      var y = document.getElementById("subpage-trade_range-year").value;
      var m = document.getElementById("subpage-trade_range-month").value;
      var d = document.getElementById("subpage-trade_range-day").value;
      var ye = document.getElementById("subpage-trade_range-end-year").value;
      var me = document.getElementById("subpage-trade_range-end-month").value;
      var de = document.getElementById("subpage-trade_range-end-day").value;
      if ( y && m && d && ye && me && de  ) {
        if ( y.match(/^\d+$/) && m.match(/^\d+$/) && d.match(/^\d+$/)
            && ye.match(/^\d+$/) && me.match(/^\d+$/) && de.match(/^\d+$/)) {
          startDate = new Date( Number(y), Number(m)-1, Number(d)  ).getTime()/1000;
          endDate = new Date( Number(ye), Number(me)-1, Number(de)  ).getTime()/1000;
        } else {
          this.dialog.show( "warn", {
            message : "表示範囲に数値が入力されていません。",
            buttons : [
              { type:"ok" }
            ]
          } );
          return;
        }
      } else {
         // 入力がなければ今月のデータを表示
        var now = new Date();
        var end = new Date( now.getFullYear(), now.getMonth()+1, 0  );
        startDate = new Date( now.getFullYear(), now.getMonth(), 1  ).getTime()/1000;
        endDate = end.getTime()/1000;

        // フィールドにも設定しておく
        document.getElementById("subpage-trade_range-year").value = now.getFullYear();
        document.getElementById("subpage-trade_range-month").value = now.getMonth()+1;
        document.getElementById("subpage-trade_range-day").value = 1;
        document.getElementById("subpage-trade_range-end-year").value = now.getFullYear();
        document.getElementById("subpage-trade_range-end-month").value = now.getMonth()+1;
        document.getElementById("subpage-trade_range-end-day").value = end.getDate();
      }
    } else {
      // バックテストの場合、全テストが対象
      startDate = this.start;
      endDate = this.end;
    }
    // ロード中に変更
    summaryEl.innerHTML= fx.template.Templates.common.loading;

    var self = this;
    // 終了時間はその日の終わりにする
    this.tradeResultServiceStub.list( this.currentProcessId, "6h", startDate, endDate+60*60*25,  function( list ) {
      // 集計
      var value = self.aggregate(list); // 集計
      summaryEl.innerHTML = fx.template.Templates.submenu.trade.summary.evaluate( value[0] );
      // 一覧
      self.tradeListTable.setData( list.sort( function( a,b ) {
        return (b.date || 0) - ( a.date || 0);
      }  ) );
      self.agentResultListTable.setData( value[1] );

    }, function(){}  ); // TODO
  },
  aggregate: function( list ) {
    var pairList = {};
    var all = this.init();
    var traders =  {};
    for ( var i=0,n=list.length;i<n;i++ ) {
      p = list[i]
      this.collect( p, all  );
      // エージェント別
      var t = p.trader || "(不明)";
      if ( !traders[t] ) {
          traders[t]  = this.init();
      }
      this.collect( p, traders[t]  );
      
      // 通貨ペア別集計
      pairList[p.pair] = !pairList[p.pair] ? 1 : pairList[p.pair]+1;
    }
    // 通貨ペアの集計結果をフォーマット
    all.pair = "";
    for( var j in pairList ) {
      if (typeof pairList[j] == "function" ) continue;
      all.pair += fx.template.Templates.submenu.trade.pair.evaluate(
          {pair:j,value:pairList[j]} );
    }
    all = this.finish( all, true );
    var tmp = [];
    for( var k in traders ) {  
      traders[k] = this.finish( traders[k], false );
      traders[k]["agentName"] = k;
      tmp.push( traders[k] );
    }
    return [ all, tmp  ];
  },
  
  /**
   * 集計データの初期オブジェクトを作成。
   */
  finish: function(obj, decorate) {
    // 平均損益
    obj.avgProfitOrLoss = obj.total > 0 ? Math.round(obj.totalProfitOrLoss / obj.total) : 0;
    // 平均保有期間
    obj.avgRange = obj.commited > 0 ? obj.totalRange / obj.commited : 0 ;
    obj.avgRange = Math.round(obj.avgRange/60);
    obj.maxRange = Math.round(obj.maxRange/60);
    obj.minRange = Math.round(obj.minRange/60);
    // 勝率
    obj.winRate = obj.total > 0 ? Math.round(obj.win*10000/obj.total)/100 : "-";
    // プロフィットレシオ
    obj.avgProfit = obj.win > 0 ? Math.round(obj.totalProfit/obj.win) : 0;
    obj.avgLoss = obj.lose > 0 ? Math.round(obj.totalLoss/obj.lose) : 0;
    obj.profitRatio = obj.avgLoss != 0 ? Math.round(obj.avgProfit*1000/(obj.avgLoss*-1))/1000 : 0;
    
    // 最大/最小系のデータが未設定出れば設定する。
    var props = ["maxSize", "minSize","maxRange","minRange" ];
    for ( i=0,n=props.length;i<n;i++ ) {
      if ( !obj[props[i]] ) { obj[props[i]] =  0; }
    }

    // 価格を修飾
    if ( decorate ) {
      props = ["totalProfitOrLoss", "maxProfit", "maxLoss", 
                   "avgProfitOrLoss","avgProfit","avgLoss","totalSwap"];
      for ( i=0,n=props.length;i<n;i++ ) {
        obj[props[i]] = this.decorateProfitOrLoss( obj[props[i]] );
      }
    }
    return obj;
  },
  
  /**
   * 集計データの初期オブジェクトを作成。
   */
  init: function() {    
    return {
      total: 0,
      commited: 0,
      sell: 0, buy: 0,
      win: 0, lose: 0, draw: 0,
      totalProfitOrLoss: 0,
      totalLoss: 0, totalProfit: 0,
      totalSwap: 0, 
      maxProfit: 0, maxLoss : 0,
      totalRange: 0
    }; 
  },
  
  /**
   * 集計する
   * @param p ポジション
   * @param obj 集計先
   */
  collect: function( p, obj  ) {
    obj.total += 1;
    if ( p.state==3 ) { // 約定済みの場合
       obj.commited += 1; // コミット数
    }
    
     // 勝敗
     if ( p.profit_or_loss < 0 ) {
       obj.lose += 1;
     } else if ( p.profit_or_loss > 0 ) {
       obj.win += 1;
     } else {
       obj.draw += 1;
     }
     // 統計
     obj.totalProfitOrLoss += p.profit_or_loss;
     obj.totalSwap +=  p.swap ? p.swap : 0;
     if ( p.profit_or_loss > 0 ) {
       obj.maxProfit = Math.max( obj.maxProfit, p.profit_or_loss) ;
       obj.totalProfit += p.profit_or_loss;
     }
     if ( p.profit_or_loss < 0 ) {
       obj.maxLoss = Math.min( obj.maxLoss, p.profit_or_loss) ;
       obj.totalLoss += p.profit_or_loss;
     }

     // 種類
     if ( p.sell_or_buy == "sell" ) {
       obj.sell += 1;
     } else {
       obj.buy += 1;
     }
     // 取引量
     obj.maxSize = obj.maxSize ?  Math.max( obj.maxSize, p.count) : p.count ;
     obj.minSize = obj.minSize ? Math.min( obj.minSize, p.count) : p.count ;
     // 保有期間
     if ( p.fix_date ) {
       var range = p.fix_date - p.date;
       obj.totalRange += range;
       obj.maxRange = obj.maxRange ?  Math.max( obj.maxRange, range) : range ;
       obj.minRange = obj.minRange ? Math.min( obj.minRange, range) : range ;
     }
  },
  
  /**
   * 損益を修飾する
   */
  decorateProfitOrLoss: function( profitOrLoss ) {
    var cl = "draw";
    if ( profitOrLoss > 0 ) {
      cl = "win";
    } else if ( profitOrLoss < 0 ){
      cl = "lose";
    }
    return "<span class='" + cl + "'>" + ( profitOrLoss > 0 ? "+" : "" ) + profitOrLoss + "</span>";
  }
}

//トレード結果一覧一覧テーブル
fx.ui.TradeListTable = function(elementId) {
  this.elementId = elementId; // @Inject
  this.table = null;
  this.ds = null;
}
fx.ui.TradeListTable.prototype = util.merge( util.BasicTable, {
  initialize: function() {
    var self = this;
    var columnDefs = [
      {key:"profit_or_loss", label:"損益", sortable:true, resizeable:true,width:70, formatter: function( cell, record, column, data){
        cell.innerHTML = "<div style='text-align:right;'>"
          + fx.ui.pages.TradeResultPage.prototype.decorateProfitOrLoss(data) 
          + "<div>"
      } },
      {key:"swap", label:"スワップ", sortable:true, resizeable:true, width:40, formatter: function( cell, record, column, data){
        cell.innerHTML = "<div style='text-align:right;'>"
          +  fx.ui.pages.TradeResultPage.prototype.decorateProfitOrLoss( data || 0 ) 
          + "<div>"
      } },
      {key:"sell_or_buy", label:"種類", sortable:true, resizeable:true,width:20, formatter: function( cell, record, column, data){
        cell.innerHTML = data == "sell" ? "売" : "買";
      } },
      {key:"state", label:"状態", sortable:true, resizeable:true,width:50,  formatter: function( cell, record, column, data){
        switch ( data ) {
          case 0 :
            cell.innerHTML = "注文中"; break;
          case 1 :
            cell.innerHTML = "所有中"; break;
          case 2 :
            cell.innerHTML = "決済注文中"; break;
          case 3 :
            cell.innerHTML = "決済済"; break;
          case 4 :
            cell.innerHTML = "ロスト"; break;
          default :
            cell.innerHTML = "不明"; break;
        }
      }},
      {key:"pair", label:"通貨ペア", sortable:true, resizeable:true, width:50 },
      {key:"rate", label:"レート", sortable:true, resizeable:true,width:50 },
      {key:"fix_rate", label:"決済レート", sortable:true, resizeable:true,width:50,formatter: function( cell, record, column, data){
        cell.innerHTML =  data ? data : "-";
      } },
      {key:"count", label:"数量", sortable:true, resizeable:true,width:30 },
      {key:"trader", label:"エージェント", sortable:true, resizeable:true,width:50,formatter: function( cell, record, column, data){
        cell.innerHTML =  data ? data : "-";
      } },
      {key:"date", label:"取引日時", sortable:true, resizeable:true,width:118, formatter: function( cell, record, column, data){
          var d = new Date(data*1000);
          cell.innerHTML =  util.formatDate(d);
      } },
      {key:"fix_date", label:"決済日時", sortable:true, resizeable:true,width:118, formatter: function( cell, record, column, data){
        if (data) {
          var d = new Date(data*1000);
          cell.innerHTML =  util.formatDate(d);
        } else {
          cell.innerHTML =  "-";
        }
      }}
    ];
    self.ds = new YAHOO.util.DataSource([]);
    self.ds.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
    self.ds.responseSchema = {
      fields: ["profit_or_loss", "swap", "sell_or_buy", "state", "pair", "rate", "fix_rate", "count","trader", "date", "fix_date"]
    };
    self.table = new YAHOO.widget.DataTable(self.elementId,
      columnDefs, self.ds, {
        selectionMode:"standard",
        scrollable: true,
        width:"620px"
      }
    );
    this.sortBy = "date"; 
    this.setBasicActions();
  }
});

//トレード結果一覧一覧テーブル
fx.ui.AgentResultListTable = function(elementId) {
  this.elementId = elementId; // @Inject
  this.table = null;
  this.ds = null;
}
fx.ui.AgentResultListTable.prototype = util.merge( util.BasicTable, {
  initialize: function() {
    var self = this;
    var columnDefs = [
      {key:"agentName", label:"名前", sortable:true, resizeable:true,width:100 },
      {key:"totalProfitOrLoss", label:"損益合計", sortable:true, resizeable:true,width:70, formatter: function( cell, record, column, data){
        cell.innerHTML = "<div style='text-align:right;'>"
          + fx.ui.pages.TradeResultPage.prototype.decorateProfitOrLoss(data) 
          + "<div>";
      } },
      {key:"totalSwap", label:"累計スワップ", sortable:true, resizeable:true,width:40, formatter: function( cell, record, column, data){
        cell.innerHTML = "<div style='text-align:right;'>"
          +  fx.ui.pages.TradeResultPage.prototype.decorateProfitOrLoss( data || 0 ) 
          + "<div>";
      } },
      {key:"total", label:"取引回数/約定済み", sortable:true, resizeable:true,width:30, formatter: function( cell, record, column, data){
        cell.innerHTML = data  + "/" + record.getData().commited;
      } },
      {key:"sell", label:"売/買", sortable:true, resizeable:true,width:30, formatter: function( cell, record, column, data){
        cell.innerHTML = data  + "/" + record.getData().buy;
      } },
      {key:"winRate", label:"勝率", sortable:true, resizeable:true,width:40, formatter: function( cell, record, column, data){
        cell.innerHTML = "<div style='text-align:right;'>" + data  + "%<div>";
      } },
      {key:"maxProfit", label:"最大利益", sortable:true, resizeable:true,width:60, formatter: function( cell, record, column, data){
        cell.innerHTML = "<div style='text-align:right;'>"
          + fx.ui.pages.TradeResultPage.prototype.decorateProfitOrLoss(data) 
          + "<div>";
      } },
      {key:"maxLoss", label:"最大損失", sortable:true, resizeable:true,width:60, formatter: function( cell, record, column, data){
        cell.innerHTML = "<div style='text-align:right;'>"
          + fx.ui.pages.TradeResultPage.prototype.decorateProfitOrLoss(data) 
          + "<div>";
      } },
      {key:"avgProfitOrLoss", label:"平均損益", sortable:true, resizeable:true,width:50, formatter: function( cell, record, column, data){
        cell.innerHTML = "<div style='text-align:right;'>"
          + fx.ui.pages.TradeResultPage.prototype.decorateProfitOrLoss(data) 
          + "<div>";
      } },
      {key:"profitRatio", label:"損益率", sortable:true, resizeable:true,width:40 }
    ];
    self.ds = new YAHOO.util.DataSource([]);
    self.ds.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
    self.ds.responseSchema = {
      fields: ["agentName","totalProfitOrLoss", "totalSwap", "total", "sell", "winRate", "maxProfit", "maxLoss", "avgProfitOrLoss","profitRatio"]
    };
    self.table = new YAHOO.widget.DataTable(self.elementId,
      columnDefs, self.ds, {
        selectionMode:"standard",
        scrollable: true,
        width:"620px"
      }
    );
    this.setBasicActions();
  }
});


//テスト情報画面
fx.ui.pages.InfoResultPage = function() {
  this.elementId = null; // @Inject
  this.processServiceStub = null; //@Inject
  this.agentSelector = null; // @Inject
  this.dialog = null; // @Inject
}
fx.ui.pages.InfoResultPage.prototype = {
  /**
   * ページを初期化する。
   * インスタンス生成時に1度だけ実行すること。
   */
  initialize: function( ) {
    // エージェント
    this.agentSelector.initialize(null, true, 300);
  },
  /**
   * このページから画面を移動する際に呼び出される。
   * 戻り値としてfalseを返すと遷移をキャンセルする。
   */
  from : function(toId) {
    // ページを非表示
    document.getElementById(this.elementId).style.display = "none";
    return true;
  },
  /**
   * このページに画面を移動すると呼び出される。
   */
  to : function( fromId, param ) {
    // ページを表示
    document.getElementById(this.elementId).style.display = "block";
    this.currentProcessId = param.id;
    this.update();
  },
  update: function() {
    var infoEl = document.getElementById( "subpage-info_info-values" );
    // ロード中に変更
    infoEl.innerHTML= fx.template.Templates.common.loading;

    var self = this;
    this.processServiceStub.get( this.currentProcessId, function( p ) {
      if ( self.currentProcessId == "rmt" ) {
        infoEl.innerHTML = fx.template.Templates.submenu.info.rmtInfo.evaluate( {
          enable: p.trade_enable ? "する" : "しない"
        });
      } else {
        var s = new Date( p.start_date*1000 );
        var e = new Date( p.end_date*1000 );
        var startStr = s.getFullYear() + "-"  + (s.getMonth()+1) + "-"  + s.getDate();
        var endStr   = e.getFullYear() + "-"  + (e.getMonth()+1) + "-"  + e.getDate();
	      infoEl.innerHTML = fx.template.Templates.submenu.info.info.evaluate( {
	        name: p.name,
	        memo: p.memo.replace(/^\s+|\s+$/g, '') || "&nbsp;",
	        range: startStr + " ～ " + endStr
	      });
      }
      // 一覧
      self.agentSelector.setAgents( p.agents );
    }, function(){}  ); // TODO
  }
}

//グラフ表示設定画面
fx.ui.pages.GraphSettingResultPage = function() {
  this.elementId = null; // @Inject
  this.processServiceStub = null; //@Inject
  this.outputServiceStub = null; //@Inject
  this.dialog = null; // @Inject
}
fx.ui.pages.GraphSettingResultPage.prototype = {

  /**
   * このページから画面を移動する際に呼び出される。
   * 戻り値としてfalseを返すと遷移をキャンセルする。
   */
  from : function(toId) {
    // ページを非表示
    document.getElementById(this.elementId).style.display = "none";
    return true;
  },
  /**
   * このページに画面を移動すると呼び出される。
   */
  to : function( fromId, param ) {
    // ページを表示
    document.getElementById(this.elementId).style.display = "block";
    this.currentProcessId = param.id;
    this.list();
  },
  /**
   * 出力一覧を表示する。
   */
  list: function() {
    var el = document.getElementById( "subpage-graph_list" );
    // ロード中に変更
    el.innerHTML= fx.template.Templates.common.loading;

    var self = this;
    this.processServiceStub.get( this.currentProcessId, function( p ) {
      self.agentNameMap = {};
      for ( var i=0,n=p.agents.length;i<n;i++ ) {
        self.agentNameMap[p.agents[i].id] = p.agents[i].name
      }
      self.outputServiceStub.list_outputs( self.currentProcessId, function( outs ) {
          var str = "";
          var index = 0;
          var tmp = [];
          for ( var i in outs ) {
            var itemBody = "";
            for ( var j in outs[i] ) {
              tmp.push( [i,j, outs[i][j]] );
              var colorsBody = "";
              for ( var k = 0; k < ( outs[i][j].column_count || 1 ); k++ ) {
                colorsBody += '<div id="submenu-graph_color_' + index + '_' + k + '"></div>';
              }
              itemBody += fx.template.Templates.submenu.graph.item.evaluate( {
                name: j,
                agentName: i,
                checked: outs[i][j]["visible"] == false ? "" : 'checked="checked"',
                id : index,
                colors: colorsBody
              } );
              index += 1;
            }
            str += fx.template.Templates.submenu.graph.agent.evaluate( {
              agentName: self.agentNameMap[i] || "(不明)",
              items: itemBody
            } );
          }
          el.innerHTML = str || '<div style="margin:10px 0px 0px 0px;">(　グラフはありません。)</div>';

          // イベントを割り当て
          self.pickers = [];
          for ( var i=0; i<index; i++ ) {
            (function() {
              self.pickers[i] = [];
              var info = tmp[i];

              // 表示/非表示
              var input = document.getElementById( "submenu-graph_checked_" + i );
              input.onchange = function() {
                // グラフに転送
                util.getSwf("chart").setGraphVisible( [info[0],info[1]], input.checked ? true : false );
                // 設定を記録
                self.updateSetting( [info[0],info[1]], {visible: input.checked ? true : false } );
              };
              // 色
              var index = i;
              var colorChanged = function() {
                debug(index);
                var colors = [];
                for ( var j = 0, n=self.pickers[index].length;j<n;j++ ) {
                  colors.push( self.pickers[index][j].get());
                }
                util.getSwf("chart").setGraphColors( [info[0],info[1]], colors );
                self.updateSetting( [info[0],info[1]], {colors: colors } );
              };
              for ( var k = 0; k < ( info[2].column_count || 1 ); k++ ) {
                var color = info[2].colors && info[2].colors[k] ? info[2].colors[k] : "#557777";
                var p = new util.ColorPicker( 'submenu-graph_color_' + i + '_' + k , color, colorChanged  );
                p.init();
                self.pickers[i].push( p );
              }
            })();
          }

      }, function(){}  ); // TODO
    }, function(){}  ); // TODO
  },
  /**
   * 設定値を記録する
   */
  updateSetting: function( target, properties ) {
    this.outputServiceStub.set_properties(
        this.currentProcessId, target, properties, null, null ); // TODO
  }
}



