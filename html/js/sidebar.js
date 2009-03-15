// ネームスペース
namespace( "fx.ui" )

fx.ui.SideBar = function() {

  this.elementId = null // @Inject
  this.processServiceStub = null; //@Inject
  this.pageManager = null; //@Inject
  this.dialog = null; // @Inject

  this.menu = new util.MenuBar( "menu", "left", "sidebar" );

  this.process = []; // プロセス一覧
  this.runnings = []; // 現在実行中のプロセス。

  // 自動更新するためのタイマー
  this.autoUpdate = null;
}
fx.ui.SideBar.prototype = {

  // 初期化する
  initialize : function(defaultPage) {

    var self = this;

    // メニュー
    this.menu.pageManager = this.pageManager;
    this.menu.initialize( defaultPage, function() {
      self.to( this.id );
    } );

    // サーバーからプロセス一覧を取得
    this.processServiceStub.list_test( function(list) {
      self.process = list;

      var container = document.getElementById( self.elementId );
      self.runnings = [];
      for ( var i=0,n=list.length; i<n; i++ ) {
        var div = self.createProcessUI( list[i] );
        container.appendChild( div );
        if ( list[i].state == "RUNNING" ||  list[i].state == "WAITING" ) {
          self.runnings.push( list[i].id );
        }
        self.setProgress( list[i] );
      }

      // 定期更新タイマーを起動
      self.autoUpdate = new util.Timer( 5*1000, function(){
        self.updateProcessList();
      }, false );
      self.autoUpdate.start();
    }, function(){} ); // TODO
  },
  to : function( page, params ) {
    var m = page.match( /sidebar\_(.*)/ );
    if ( m ) {
      var m2 = m[1].match( /result_(.*)/ );
      var m3 = m[1].match( /agent_edit_(.*)/ );
      if ( m2 ) {
        if ( m2[1] == "rmt" ) {
            this.menu.to( "result", {
              id:m2[1],
              menuId: m[1]
            } );
        } else{
          for ( var i=0,n=this.process.length; i<n; i++ ) {
            if ( m2[1] == this.process[i].id ) {
              this.menu.to( "result", {
                id:m2[1],
                menuId: m[1],
                name: this.process[i].name,
                start: this.process[i].start_date,
                end: this.process[i].end_date
              } );
            }
          }
        }
      } else if ( m3 ) {
         this.menu.to( "agent_edit", {
           id:m3[1],
           menuId: m[1]
         } );
      } else {
        this.menu.to( m[1], params );
      }
    }
    // UIを更新
    for ( var i=0,n=this.process.length; i<n; i++ ) {
      var div = document.getElementById( "process_" + this.process[i].id);
      if ( !div ) { continue; }
      if ( m2 && this.process[i].id == m2[1] ) {
         div.className = "process_selected"
      } else {
         div.className = "process"
      }
    }
  },
  // プロセス一覧を更新する
  updateProcessList : function() {
    if ( this.runnings.length <= 0 ) return;
    var self = this;
    this.processServiceStub.status( this.runnings, function(list) {
      var map = {};
      for ( var i=0,n=list.length;i<n;i++ ) {
        map[list[i].id] = list[i];
      }
      var tmp = [];
      for ( var i=0,n=self.runnings.length;i<n;i++ ) {
        var p = map[self.runnings[i]];
        if (!p // 通信中に追加された場合、nullになる。
            || (p.state == "RUNNING" && p.progress < 100)
            || (p.state == "WAITING")   ) {
          tmp.push( self.runnings[i] );
        }
        if ( p ) {
          self.setProgress( p );
        }
      }
      self.runnings = tmp;

      if ( self.runnings.length <= 0 && self.autoUpdate ) {
        self.autoUpdate.stop();
      } else {
        self.autoUpdate.start();
      }
    }, function(){} ); // TODO
  },

  remove : function( processId ) {
    var self = this;
    this.dialog.show( "input", {
        message : "バックテストを削除します。よろしいですか?",
        buttons : [
           { type:"ok", action: function(dialog){
             self.processServiceStub.delete_test( processId, function(p) {
               var tmp = [];
               for ( var i=0,n=self.runnings.length;i<n;i++ ) {
                 if ( self.runnings[i] != processId ) tmp.push( self.runnings[i] );
               }
               self.runnings = tmp;

               var div = document.getElementById( "process_" + processId);
               div.parentNode.removeChild(div);

             }, function(){} ); // TODO
           } },
           { type:"cancel" }
        ]
    } );
  },

  add : function( processId ){
    var self = this;
    this.processServiceStub.get( processId, function(p) {
      var container = document.getElementById( self.elementId );
      var div = self.createProcessUI( p );
      if ( container.firstChild ) {
         container.insertBefore(div, container.firstChild);
      } else {
        container.appendChild( div );
      }
      self.setProgress( p );

	    // 先頭に追加
	    self.process.push( p );
	    self.runnings.push( p.id )
	    self.autoUpdate.start(); // 定期更新を再開
    }, function(){} ); // TODO
  },

  // テストの進捗を更新する。
  setProgress : function( p ) {
    // 背景画像を移動
    // 進捗が100以上ならステータスバーは非表示
    var e = document.getElementById( "process_" + p.id + "_progress" );
    var state = document.getElementById( "process_" + p.id + "_state" );
    var name = document.getElementById( "process_" + p.id + "_name" );

    if ( p.state == "RUNNING" && p.progress < 100 ) {
      e.style.display = "block";
      var value = document.getElementById( "process_" + p.id + "_progress_value" );
      value.innerHTML = p.progress + "%";
      var bar = document.getElementById( "process_" + p.id + "_progress_bar" );
      bar.style.backgroundPosition = (-180+Number(p.progress)) + "px 0px";
      state.innerHTML = this.stateToDisplayName( p.state);
    } else if ( p.state == "WAITING" ) {
      e.style.display = "none";
      state.innerHTML = this.stateToDisplayName( p.state );
    } else {
      e.style.display = "none";
      state.innerHTML = this.stateToDisplayName( p.state == "RUNNING" ? "FINISHED" : p.state );
      // 実行結果へのリンクを有効化する。
      name.innerHTML = '<a href="javascript:fx.app.sideBar.to( \'sidebar_result_' + p.id + '\' );">' + p.name + "</a>";
    }
  },

  /**
   * プロセスの表示用UIを作成する
   */
  createProcessUI : function( process ) {
    var div = document.createElement("div");
    div.className = "process";
    div.id = "process_" + process.id;
    div.innerHTML = fx.template.Templates.sidebar.process.evaluate({
       id : process.id,
       name : process.name,
       date : util.formatDate(new Date(process.create_date*1000)),
       state : this.stateToDisplayName( process.state)
    });
    return div;
  },
  /**
   * 状態の文字列を表示用の名前に変換する。
   */
  stateToDisplayName : function(state) {
    if( state == "WAITING" ) {
      return "待機中";
    } else if( state == "RUNNING" ) {
      return "実行中";
    } else if( state == "CANCELED" ) {
      return "中止";
    } else if( state == "FINISHED" ) {
      return "完了";
    } else if( state == "ERROR_END" ) {
      return "<span class='error'>エラー終了</span>";
    }
  }
}

// トレード状態表示
fx.ui.TradeEnable = function(elementId){
  this.elementId = elementId;  //@Inject
  this.processServiceStub = null; //@Inject
}
fx.ui.TradeEnable.prototype = {
  init: function() {
    var self = this;
    this.processServiceStub.get( "rmt", function( p ) {
       self.set( p["trade_enable"] );
    }, null ); // TODO
  },
  set: function( enable ) {
     document.getElementById( this.elementId ).src =
       enable ? "./img/auto_trade_on.gif" : "./img/auto_trade_off.gif";
  }
}
