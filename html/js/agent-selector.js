
// ネームスペース
namespace( "fx.agent" )
namespace( "fx.agent.ui" )

// エージェント選択UI
fx.agent.ui.AgentSelector = function( id ) {

  this.id = id; //@Inject
  this.agentServiceStub = null; //@Inject

  this.agentClassListTable = null;
  this.agentListTable = null;
  this.agentPropertyEditor = null;

  this.dialog = null; // @Inject

  // データ
  this.agentClasses = null;
}
fx.agent.ui.AgentSelector.prototype = {
  initialize: function( data, readOnly, tableWidth ) {
    var self = this;

    this.readOnly = readOnly;
    this.agentClassListTable = new fx.agent.ui.AgentClassListTable( );
    this.agentListTable = new fx.agent.ui.AgentListTable( this.id + "__list", tableWidth );
    this.agentPropertyEditor = this.readOnly
       ? new fx.agent.ui.AgentPropertyEditorReadOnly( this.id + "__editor", this )
       : new fx.agent.ui.AgentPropertyEditor( this.id + "__editor", this );

    this.agentListTable.initialize();
    this.agentPropertyEditor.initialize();

    var self = this;
    this.agentListTable.table.subscribe("rowSelectEvent", function(ev) {
      self.selectionChanged();
    });
    this.agentListTable.table.subscribe("rowUnselectEvent", function(ev) {
      self.selectionChanged();
    });

    // ボタン
    if ( !this.readOnly ) {
      this.addButton = new util.Button(this.id + "__add", "add", function() {
        self.add();
      }, "追加");
      this.addButton.setEnable( true );

      this.removeButton = new util.Button(this.id + "__remove", "remove", function() {
        self.remove();
      }, "削除");
      this.removeButton.setEnable( false );
    }
  },
  /**
   * エージェントを設定する
   */
  setAgents : function(data) {
    if ( data ) {
      this.agentListTable.setData(data);
      if ( !this.readOnly ) {
        this.checkDuplicateName();
      }
      // エディタのデータも初期化
      this.agentPropertyEditor.initialize();
    }
  },
  /**
   * エージェントを取得する
   */
  getAgents: function() {
    // 編集中なら、編集を確定
    if ( this.isEditing() ) {
      this.edit();
    }
    var agents = [];
    var rs = this.agentListTable.table.getRecordSet().getRecords( 0, this.agentListTable.length() );
    for ( var j=0,s=rs.length;j<s; j++) {
      agents.push( rs[j].getData() );
    }
    return agents;
  },

  /**
   * エラーがあるか評価する。
   */
  hasError : function(){
    var agents = this.getAgents( );
    for ( var j=0,s=agents.length;j<s; j++) {
      if ( agents[j].state === "error" || agents[j].duplicate_name_error ) {
        return true;
      }
    }
    return false;
  },

  // 追加開始
  add: function(){
    // エージェント一覧、プロパティエディタを表示
    var self = this;
    var msg = "追加するエージェントを選択してください。"
      + '<div style="margin-top:10px;border: 1px solid #FFFFFF;">'
      + '  <div id="agent_class_list"></div>'
      + '</div>';
    this.dialog.show( "input", {
      message : msg,
      init : function( dialog ) {
        // クラス一覧を初期化。
        self.agentClassListTable.elementId = "agent_class_list";
        self.agentClassListTable.initialize();
        self.listAgentClass( false, function( data ) {
          self.agentClasses = data;
          self.agentClassListTable.setData(data);
          if ( data.length > 0 ) {
            self.agentClassListTable.table.selectRow(0);
          }
        }, null ); // TODO
      },
      buttons : [
        { type:"ok", action: function(dialog){

            var selectedRowIds = self.agentClassListTable.table.getSelectedRows();
            var error = null;
            if ( selectedRowIds <= 0 ) {
              error = "エージェントが選択されていません。";
            }
            if ( !error ) {
              var agents = [];
              for ( var i = 0; i < selectedRowIds.length; i++ )  {
                var record = self.agentClassListTable.table.getRecord( selectedRowIds[i] );
                agents.push( record.getData() );
              }
            }

            if (error) {
              dialog.content.innerHTML = '<div class="warn_msg">※'
                   + error + '</div>' + msg;
              self.agentClassListTable.elementId = "agent_class_list";
               self.agentClassListTable.initialize();
               self.agentClassListTable.setData(self.agentClasses);
              return false;
            } else {
              self._add( agents );
            }
        } },
        { type:"cancel" }
      ]
    } );


  },
  // 追加
  _add: function( newAgents ){

    // 利用されている名前
    var set = {};
    var rs = this.agentListTable.table.getRecordSet().getRecords( 0,
        this.agentListTable.table.getRecordSet().getLength() );
    for ( var j=0,s=rs.length;j<s; j++) {
      set[rs[j].getData().name] = "exist";
    }

    // 名前を追加。
    for ( var i=0; i<newAgents.length; i++) {
      var k = 1;
      while ( set["名称未設定エージェント"+k] ) { k++; }

      // 初期値からプロパティ値を作成
      var defs = newAgents[i].properties;
      var prop = {};
      var def  = {};
      for ( var j=0, s=defs.length;j<s;j++  ) {
        def[defs[j]["id"]] = defs[j];
        prop[defs[j]["id"]] = defs[j]["default"] || "";
      }

      var a = {
        "id": UUID.generate(),
        "name": "名称未設定エージェント"+k,
        "class":newAgents[i].class_name + "@" + newAgents[i].file_name,
        "class_name":newAgents[i].class_name,
        "file_name":newAgents[i].file_name,
        "description":newAgents[i].description,
        "property_def":def,
        "properties":prop
      };
      this.agentListTable.add( a ); // テーブルを更新
    }
    this.selectionChanged();
  },
  // 削除
  remove: function(){

    // 編集中なら、編集を確定
    if ( this.isEditing() ) {
      this.edit();
    }

    // 選択されている行を取得
    var selectedRowIds = this.agentListTable.table.getSelectedTrEls();
    if ( selectedRowIds.length <= 0 ) {
      return;
    }
    // 確認
    var self = this;
    var msg = "削除します。よろしいですか?";
    this.dialog.show( "input", {
      message : msg,
      buttons : [
        { type:"ok", action: function(dialog){
            // 行のデータを削除
           for( var j=0,s=selectedRowIds.length;j<s;j++ ) {
             self.agentListTable.remove( selectedRowIds[j] );
           }
           self.agentListTable.table.unselectAllRows();
           self.selectionChanged();
        }},
        { type:"cancel",
          alt: "キャンセル",
          key: "Esc"
        }
      ]
    });
  },

  /**
   * 選択状態が更新された
   */
  selectionChanged: function() {

    // 編集中なら、編集を確定
    if ( this.isEditing() ) {
      this.edit();
    }

    // 選択されている行を取得
    var self = this;
    var selectedRowIds = this.agentListTable.table.getSelectedRows();
    var removeEnable = false;
    if ( selectedRowIds.length <= 0 ) {
      // 選択なし
      removeEnable = false;
      self.agentPropertyEditor.clear( "エージェントを選択してください。" );
    } else if ( selectedRowIds.length == 1 ) {
      removeEnable = true;
      // エディタも更新する。
      var selectedEl = this.agentListTable.table.getSelectedTrEls()[0];
      this.agentPropertyEditor.target =  this.agentListTable.table.getRecord  (selectedRowIds[0]);
      var data = this.agentListTable.table.getRecord( selectedRowIds[0] ).getData();
      self.agentPropertyEditor.set( data );
    } else {
      removeEnable = true;
      // エディタは初期化
      self.agentPropertyEditor.clear( "---" );
    }
    //  削除の状態更新
    if ( !this.readOnly ) {
      this.removeButton.setEnable(removeEnable);
    }
  },

  /**
   * プロパティを保存
   */
  edit: function(){
    if ( this.readOnly ) return;
    var newData = this.agentPropertyEditor.get();
    if ( newData ) {
      this.agentListTable.update( this.agentPropertyEditor.target, newData );
      this.agentPropertyEditor.target = null;
      this.agentPropertyEditor.end();

      this.checkDuplicateName();
    }
  },
  // 名前の重複をチェックする
  checkDuplicateName : function() {
    // 重複チェック
    var rs = this.agentListTable.table.getRecordSet().getRecords( 0, this.agentListTable.length() );
    for( var i=0, n=rs.length; i<n; i++  ) {
      var a = rs[i].getData();
      var org = a.duplicate_name;
      delete a.duplicate_name;
      for( var j=0; j<n; j++  ) {
        if ( i == j ) continue;
        var b = rs[j].getData();
        if ( a.name === b.name ) {
          if ( !a.duplicate_name )
            a.duplicate_name = true;
            this.agentListTable.update( rs[i], a );
          }
        if ( !b.duplicate_name ) {
            b.duplicate_name = true;
            this.agentListTable.update( rs[j], b );
        }
      }
      if ( !a.duplicate_name && org ) {
        this.agentListTable.update( rs[i], a );
      }
    }
  },

  /**
   * 編集中かどうか評価する。
   */
  isEditing : function() {
    return this.agentPropertyEditor.editing ? true : false
  },

  /**
   * エージェントクラスの一覧を取得する。
   * @param {Boolean} reload 再読み込みするかどうか
   * @param {Function} success 成功時のコールバック
   * @param {Function} fail 失敗時のコールバック
   */
  listAgentClass : function( reload, success, fail ) {
    var self = this;
//    if ( !this.agentClasses || reload ) {
      this.agentServiceStub.list_agent_class( function( data ) {
        self.agentClasses = data;
        success(data);
      }, fail );
//    } else {
//      success(this.agentClasses);
//    }
  }
}


// エージェントクラス一覧テーブル
fx.agent.ui.AgentClassListTable = function( elementId ) {
  this.elementId = elementId; // @Inject
  this.table = null;
  this.ds = null;
}
fx.agent.ui.AgentClassListTable.prototype = util.merge( util.BasicTable, {
  initialize: function() {
    var self = this;
    var columnDefs = [
      {key:"class_name", label:"クラス", sortable:true, resizeable:true, width:80 },
      {key:"file_name", label:"ファイル", sortable:true, resizeable:true, width:80 },
      {key:"description", label:"説明", sortable:true, resizeable:true, formatter: function( cell, record, column, data){
        cell.innerHTML =  "<pre>" +  data + "</pre>";
      }}
    ];
    self.ds = new YAHOO.util.DataSource([]);
    self.ds.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
    self.ds.responseSchema = {
      fields: ["class_name","description", "file_name", "properties"]
    };
    self.table = new YAHOO.widget.ScrollingDataTable( self.elementId,
      columnDefs, self.ds, {
        selectionMode:"single",
        scrollable: true,
        width: "360px",
        height: "250px"
      }
    );
    this.setBasicActions();
  }
});
// エージェント一覧テーブル
fx.agent.ui.AgentListTable = function(elementId, tableWidth) {
  this.elementId = elementId; // @Inject
  this.tableWidth =  tableWidth;
  this.table = null;
  this.ds = null;
}
fx.agent.ui.AgentListTable.prototype = util.merge( util.BasicTable, {
  initialize: function() {
    var self = this;
    var columnDefs = [
      {key:"name", label:"名前", sortable:true, resizeable:true, width:100, formatter: function( cell, record, column, data){
        var str = data.escapeHTML();
        if ( record.getData().state === "error" || record.getData().duplicate_name_error ) {
          str = '<div class="problem"><span style="padding-right:3px;padding-top:2px;"><img src="./img/problem.gif" alt="問題" /></span>' + str + '</div>';
        }
        cell.innerHTML =  str;
      }},
      {key:"class_name", label:"クラス", sortable:true, resizeable:true, width:80 },
      {key:"file_name", label:"ファイル", sortable:true, resizeable:true,width:80 },
      {key:"properties", label:"プロパティ", sortable:true, resizeable:true, width:250, formatter: function( cell, record, column, data){
        var str = "";
        for( var k in data ) {
          str += String(record.getData().property_def[k].name) + "=" + String(data[k]) + ", ";
          if ( str.length > 500 ) {  break; }
        }
        cell.innerHTML =  str;
      }}
    ];
    self.ds = new YAHOO.util.DataSource([]);
    self.ds.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
    self.ds.responseSchema = {
      fields: ["name", "class_name", "description", "file_name", "properties", "state"]
    };
    self.table = new YAHOO.widget.DataTable(self.elementId,
      columnDefs, self.ds, {
        selectionMode:"standard",
        scrollable: true,
        width: (this.tableWidth || 380) + "px"
      }
    );
    this.setBasicActions();
  }
});

// エージェントプロパティエディタ
fx.agent.ui.AgentPropertyEditor = function( elementId, agentsSelector ) {
  this.elementId = elementId; // @Inject
  this.agentsSelector = agentsSelector;
  this.editing = null;
}
fx.agent.ui.AgentPropertyEditor.prototype = {

  initialize: function() {
    document.getElementById( this.elementId ).innerHTML =
      fx.template.Templates.agentPropertyEditor.none.evaluate({});
    this.editing = null;
  },
  // 名前の制約条件
  NAME_RESTRICT : {
    type: "name",
    restrict: { nullable:false, length:100, format: /[^\r\n\t\\\/\|\;]/ }
  },
  /**
   * プロパティ編集UIを表示する。
   * @param {Object} properties
   */
  set : function( agent ) {
    var self = this;
    this.editing = util.merge({}, agent);
    var props = "";
    for ( var i in agent.property_def ) {
      props += fx.template.Templates.agentPropertyEditor.property.evaluate({
        "name": agent.property_def[i].name,
        "id": agent.property_def[i].id,
        "default": agent.properties[agent.property_def[i].id] || agent.property_def[i]["default"]
      });
    }
    var info = {
      "id": this.elementId,
      "class_name":agent.class_name,
      "name": agent.name,
      "desc": agent.description,
      "properties":props
    };
    document.getElementById( this.elementId ).innerHTML =
      fx.template.Templates.agentPropertyEditor.selected.evaluate(info);

    // 値のチェック処理を追加
    this.validators = {};
    this.setValidator( "agent_name", this.NAME_RESTRICT );
    for ( var i in agent.property_def ) {
      var id = "property_" + agent.property_def[i].id;
      this.setValidator( id, agent.property_def[i] );
    }
  },
  // フォーカスロストでのバリデータを仕込む
  setValidator : function( id, def ) {
    this.validators[id] = def; // getでの取得時に評価するため記録しておく。
     var self = this;
     var input = document.getElementById( id );
     var f  = function() {
       var value = input.value;
       var error =  self.validate[def.type].call(
         self, value, def.restrict );
       var el = document.getElementById( id+"_problem" );
       if ( error ) {
         el.innerHTML = "※"+error;
         el.style.display =  "block";
       } else {
         el.innerHTML = "";
         el.style.display =  "none";
       }
     }
     // 初期値のチェック
     f();
     input.onblur = f;
  },

  /**
   * 編集されたプロパティを取得する。
   */
  get : function() {
    if ( !this.editing ) { return null; }
    var error = null;
    var form = document.forms["agent-property-editor-form_" + this.elementId];
    for ( var i=0; i<form.elements.length; i++ ) {
      var input = form.elements[i];
      var value = input.value;
      if ( input["name"] == "agent_name" ) {
        var def = this.validators["agent_name"];
        error = error || this.validate[def.type].call( this, value, def );
        this.editing["name"] = !error ? this.convert[def.type].call( this, value ) : value ;
      } else if ( input["name"].match(/^property\_(.+)$/)  ) {
        var id = RegExp.$1;
        var def = this.validators["property_" + id];
        error = error || this.validate[def.type].call( this, this.editing["properties"][id], def );
        this.editing["properties"][id] =  !error ? this.convert[def.type].call( this, value ) : value ;
      }
    }
    this.editing["state"] = error ? "error" : "";
    return this.editing;
  },
  end : function() {
    this.editing = null;
  },
  /**
   * 何も編集していない状態にする。
   */
  clear : function (str) {
    var str = str || "";
    document.getElementById( this.elementId ).innerHTML =str;
  },

  /**
   * プロパティ値の変換を行なう関数群
   */
  convert : {
    name : function( value ) { return value; },
    string : function( value ) { return value; },
    number : function( value ) {
      return value ?  Number( value ) : null;
    }
  },

  /**
   * プロパティの値チェックを行なう関数群
   */
  validate : {
    name : function( value, restrict ) {
	     restrict = restrict || {};
	     var error = this.validate.string.call( this, value, restrict );
       if ( !error ) {
          // 重複チェック
         var rs = this.agentsSelector.agentListTable.table.getRecordSet().getRecords( 0, this.agentsSelector.agentListTable.length() );
          for ( var i=0,n=rs.length;i<n;i++) {
            if ( rs[i].getData().name == value && this.editing.id !=  rs[i].getData().id ) {
              error = "名前が重複しています。";
              break;
            }
          }
       }
       return error;
    },
    string : function( value, restrict ) {
      restrict = restrict || {};
      var error = this.validate.nullable( value, restrict );
      if ( value ) {
        if ( restrict.length > 0 && value.length >= restrict.length ) {
          error = "値が長すぎます。";
        }
        if ( util.CONTROLL_CODE.test( value )  ) {
          error = "使用できない文字が含まれています。";
        }
        if ( restrict.format && !new RegExp( restrict.format ).test( value ) ) {
          error = "値のフォーマットが不正です。";
        }
      }
      return error;
    },
    number : function( value, restrict ) {
      restrict = restrict || {};
      var error = this.validate.nullable( value, restrict );
      if ( value ) {
        if ( (restrict.max != null && Number( value ) > restrict.max )
          || ( restrict.min != null && Number( value ) < restrict.min )  ) {
          error = "値が範囲外です。";
        }
        if ( !/^[\-\.\d]+$/.test( value ) ) {
          error = "数値を入力してください。";
        }
      }
      return error;
    },
    nullable : function( value, restrict ) {
      if ( !value && !restrict.nullable ) {
        return "値が入力されていません。";
      } else {
        return null;
      }
    }
  }
}


//エージェントプロパティエディタ(読み込み専用)
fx.agent.ui.AgentPropertyEditorReadOnly = function( elementId, agentsSelector ) {
  this.elementId = elementId; // @Inject
  this.agentsSelector = agentsSelector;
  this.editing = null;
}
fx.agent.ui.AgentPropertyEditorReadOnly.prototype = {

  initialize: function() {
   document.getElementById( this.elementId ).innerHTML =
     fx.template.Templates.agentPropertyEditor.none.evaluate({});
   this.editing = null;
  },
  /**
    * プロパティ編集UIを表示する。
    * @param {Object} properties
    */
  set : function( agent ) {
   var self = this;
   this.editing = util.merge({}, agent);
   var props = "";
   for ( var i in agent.property_def ) {
     props += fx.template.Templates.agentPropertyEditor.propertyReadOnly.evaluate({
       "name": agent.property_def[i].name,
       "id": agent.property_def[i].id,
       "default": agent.properties[agent.property_def[i].id] || agent.property_def[i]["default"]
     });
   }
   var info = {
     "id": this.elementId,
     "class_name":agent.class_name,
     "name": agent.name,
     "desc": agent.description,
     "properties":props
   };
   document.getElementById( this.elementId ).innerHTML =
     fx.template.Templates.agentPropertyEditor.selectedReadOnly.evaluate(info);
  },
  /**
   * 編集されたプロパティを取得する。
   */
  get : function() {
    return null;
  },
  end : function() {
    this.editing = null;
  },
  /**
   * 何も編集していない状態にする。
   */
  clear : function (str) {
    var str = str || "";
    document.getElementById( this.elementId ).innerHTML =str;
  }
}