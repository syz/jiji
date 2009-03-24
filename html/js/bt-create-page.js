
// ネームスペース
namespace( "fx.ui.pages" )

// バックテスト作成画面
fx.ui.pages.BtCreatePage = function() {
  this.elementId = null // @Inject
  this.processServiceStub = null; //@Inject
  this.rateServiceStub = null; //@Inject

  this.agentSelector = null; //@Inject
  this.dialog = null; // @Inject
  this.topicPath = null; // @Inject

  // ボタン
  var self = this;
  this.startButton = new util.Button("bt-create__start", "start", function() {
    self.start();
  });
  this.startButton.setEnable( true );

  // カレンダー
  this.startCalendar = new util.DateInput( "bt-create_range-start", "開始日" );
  this.startCalendar.initialize();
  this.endCalendar = new util.DateInput( "bt-create_range-end",  "終了日");
  this.endCalendar.initialize();
}
fx.ui.pages.BtCreatePage.prototype = {

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
  to : function( fromId ) {
    // ページを表示
    document.getElementById(this.elementId).style.display = "block";

    var msg = document.getElementById("bt-create_msg");
    msg.innerHTML = "";
    msg.style.display = "none";

    this.topicPath.set( "バックテスト:新規作成" );

    // 利用可能な日時
    var self = this;
    if ( this.startCalendar ) this.startCalendar.destroy();
    if ( this.endCalendar ) this.endCalendar.destroy();
    document.getElementById("bt-create_range-start").innerHTML =
      fx.template.Templates.common.loading;

    this.rateServiceStub.range( "EURJPY", function(range) {
      self.startCalendar = new util.DateInput( "bt-create_range-start", "開始日",
        range.first*1000, range.last*1000 );
      self.startCalendar.initialize();
      var f = function(){ self.dateChanged();};
      self.startCalendar.listener.addListener( "selected", f );
      self.startCalendar.listener.addListener( "blur", f );
      self.endCalendar = new util.DateInput( "bt-create_range-end",  "終了日",
        range.first*1000, range.last*1000 );
      self.endCalendar.initialize();
      self.endCalendar.listener.addListener( "selected", f );
      self.endCalendar.listener.addListener( "blur", f );
    }, null ); // TODO
    
    // セレクタを初期化。
    this.agentSelector.setAgents([]);
  },
  /**
   * ページを初期化する。
   * インスタンス生成時に1度だけ実行すること。
   */
  initialize: function( ) {

    //
    // エージェント
    this.agentSelector.initialize();
  },
  start: function(){

    // エラーチェック
    if ( this.agentSelector.hasError() ) {
      this.dialog.show( "warn", {
        message : "エージェントの設定に問題があります。",
        buttons : [
          { type:"ok" }
        ]
      } );
      return;
    }

    // 名前
    var name = document.getElementById("bt-create_name").value;
    if ( !name ) {
      this.dialog.show( "warn", {
        message : "名前が入力されていません。",
        buttons : [ { type:"ok" }]
      } );
      return;
    }

    // 開始日時、終了日時
    var startDate = this.startCalendar.getDate();
    if ( !startDate ) {
      this.dialog.show( "warn", {
        message : "開始日が入力されていないか、フォーマットが不正です。",
        buttons : [ { type:"ok" }]
      } );
      return;
    }

    var endDate = this.endCalendar.getDate();
    if ( !endDate ) {
      this.dialog.show( "warn", {
        message : "終了日が入力されていないか、フォーマットが不正です。",
        buttons : [{ type:"ok" }]
      } );
      return;
    }
    if ( endDate.getTime() <= startDate.getTime() ) {
      this.dialog.show( "warn", {
        message : "開始日または終了日が不正です。",
        buttons : [{ type:"ok" }]
      } );
      return;
    }
    var agents = this.agentSelector.getAgents();

    // ダイアログを開く
    var self = this;
    this.dialog.show( "input", {
      message : "バックテストを開始します。よろしいですか?<br/>",
      buttons : [
        { type:"ok", action: function(dialog){
          var memo = document.getElementById("bt-create_memo").value;
          self.processServiceStub.new_test( name, memo,
            startDate.getTime()/1000, endDate.getTime()/1000, agents, function(info) {

            // サイドバーに追加
            self.sideBar.add(info.id);

            // 更新時刻を表示
            var dateStr = util.formatDate( new Date(info.create_date*1000) );
            var msg = document.getElementById("bt-create_msg");
            msg.innerHTML = "※開始しました。( " + dateStr + " )";
            msg.style.display = "block";
          },  function(error){
            self.dialog.show( "warn", {
              message : fx.template.Templates.btcreate.start.error.evaluate({"error":error[0].error})
            });
          } ); 
        } },
        { type:"cancel" }
      ]
    } );
  },
  /**
   * 日時の要約パネルを更新する
   */
  dateChanged: function( ){
    var el = document.getElementById("bt-create__range-summary");
    var s = this.startCalendar.getDate();
    var e = this.endCalendar.getDate();
    if ( !s || !e ) { 
      el.innerHTML = fx.template.Templates.btcreate.dateSummary.notSelect;
      return;
    }
    if ( s.getTime() >= e.getTime() ) {
      el.innerHTML = fx.template.Templates.btcreate.dateSummary.error;
      return;
    }
    var day = Math.floor( (e.getTime() - s.getTime()) / 1000 / 60 / 60 / 24 );
    var time = day * 5;
    var str = "";
    var h = Math.floor(time/60);
    if ( h > 0 ) str = h + fx.template.Templates.common.date.h;
    str += (time%60) + fx.template.Templates.common.date.mm ;
    el.innerHTML = fx.template.Templates.btcreate.dateSummary.selected.evaluate( {
      range : day + fx.template.Templates.common.date.d, 
      time: str
    } );
     
  }
}
