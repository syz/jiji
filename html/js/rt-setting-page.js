
// ネームスペース
namespace( "fx.ui.pages" )

// バックテスト新規作成
fx.ui.pages.RtSettingPage = function() {
  this.elementId = null // @Inject
  this.processServiceStub = null; //@Inject

  this.agentSelector = null; //@Inject
  this.dialog = null; // @Inject
  this.topicPath = null; // @Inject
  this.tradeEnable = null; // @Inject

  // ボタン
  var self = this;
  this.applyButton = new util.Button("rt-setting__ok", "apply", function() {
    self.ok();
  });
  this.applyButton.setEnable( true );
}
fx.ui.pages.RtSettingPage.prototype = {

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

    var msg = document.getElementById("rt-setting_msg");
    msg.innerHTML = "";
    msg.style.display = "none";

    this.topicPath.set( "リアルトレード:設定" );

    // 既存の設定情報を取得
    this.reloadAgents();
  },
  initialize: function( ) {
    this.agentSelector.initialize();
  },
  reloadAgents : function() {
    var self = this;
    this.getSetting( function( data ) {
      document.getElementById("rt-setting_trade-enable").checked =
        (data["trade_enable"] == true );
      self.agentSelector.setAgents( data["agents"] );
    }, null ); // TODO
  },

  ok: function(){

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
    var agents = this.agentSelector.getAgents();

    // ダイアログを開く
    var self = this;
    this.dialog.show( "input", {
      message : "設定を反映します。よろしいですか?<br/>",
      buttons : [
        { type:"ok", action: function(dialog){
          var enable = document.getElementById("rt-setting_trade-enable").checked;
          self.updateSetting( enable, agents, function() {
            // 更新時刻を表示 // TODO
            var dateStr = util.formatDate( new Date() );
            var msg = document.getElementById("rt-setting_msg");
            msg.innerHTML = "※設定を反映しました。( " + dateStr + " )";
            msg.style.display = "block";

            // 自動更新設定を更新
            self.tradeEnable.set( enable );

          }, null ); //TODO
        } },
        { type:"cancel" }
      ]
    } );
  },

  /**
   * 設定値を取得する。
   * @param {Function} success 成功時のコールバック
   * @param {Function} fail 失敗時のコールバック
   */
  getSetting : function( success, fail ) {
    this.processServiceStub.get( "rmt", success, fail );
  },

  /**
   * 設定値を反映する
   * @param {Boolean} tradeEnable 取引を行なうか
   * @param {Object} agents エージェントとプロパティ一覧
   * @param {Function} success 成功時のコールバック
   * @param {Function} fail 失敗時のコールバック
   */
  updateSetting : function( tradeEnable, agents, success, fail ) {
    this.processServiceStub.set( "rmt", {
      "trade_enable": tradeEnable,
      "agents": agents
    }, success, fail );
  }
}
