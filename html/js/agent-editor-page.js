
// ネームスペース
namespace( "fx.ui" )
namespace( "fx.ui.pages" )

// エージェント追加/編集UI
fx.ui.pages.AgentEditorPage = function() {
  this.elementId = null // @Inject
  this.agentServiceStub = null; //@Inject
  this.agentFileListTable = null; //@Inject
  this.dialog = null; // @Inject
  this.topicPath = null; // @Inject

    // データ
  this.agentFiles = null;
  // 編集中のファイル
  this.editingFile = null;

  // ボタン
  var self = this;
  this.addButton = new util.Button("agent-edit_add", "add", function() {
    self.add();
  }, fx.template.Templates.common.button.add);
  this.addButton.setEnable( true );

  this.removeButton = new util.Button("agent-edit_remove", "remove", function() {
    self.remove();
  }, fx.template.Templates.common.button.del);
  this.removeButton.setEnable( true );

  this.saveButton = new util.Button("agent-edit_save", "save", function() {
    if ( !self.editingFile ) { return; }
    var newData = agent_editor.getCode();
    newData = newData.strip();
    self.save(true,self.editingFile, self.target, newData);
  }, fx.template.Templates.common.button.save);
  this.saveButton.setEnable( false );
  
  // 自動保存するためのタイマー
//  this.autoSave = new util.Timer( 1000*10, function(){ self.save(); }, false );
}
fx.ui.pages.AgentEditorPage.prototype = {

  /**
   * このページから画面を移動する際に呼び出される。
   * 戻り値としてfalseを返すと遷移をキャンセルする。
   */
  from : function(toId) {
    // 自動更新タイマーを停止
//    this.autoSave.stop();
  
    // 変更を強制的に反映するため、一旦保存
    var self = this;
    this.saveIfNotSaved(function(){
      self.clearEdit();
    });
    
    // ページを非表示
    document.getElementById(this.elementId).style.display = "none";
    this.topicPath.set("");
    return true;
  },
  /**
   * このページに画面を移動すると呼び出される。
   */
  to : function( fromId, param ) {

    this.target = param["id"];

    // ページを表示
    document.getElementById(this.elementId).style.display = "block";
    var frames = document.getElementById("agent-editor-body").getElementsByTagName("iframe")
    for ( var i = 0 ; i < frames.length; i++ ) {
        frames[i].style.width = "500px";
        frames[i].style.height = "600px";
    }
    this.topicPath.set( this.target == "agent"
        ? fx.template.Templates.agentEditor.topicPath.agent
        : fx.template.Templates.agentEditor.topicPath.sharedLib );

    document.getElementById("agent_edit_desc").innerHTML =  
      this.target == "agent" ?  fx.template.Templates.agentEditor.desc.agent : fx.template.Templates.agentEditor.desc.sharedLib;
    
    this.clearEdit();
    
    // ファイル一覧を更新
    this.initialize();
  },

  initialize: function( ) {
    var self = this;
    self.editingFile = null;
    agent_editor.setCode("\n");
    this.agentFileListTable.initialize();
    this.agentFileListTable.table.subscribe("rowSelectEvent", function(ev){
      self.selectionChanged();
    });
    this.agentFileListTable.table.subscribe("rowUnselectEvent", function(ev){
      self.selectionChanged();
    });
    this.agentFileListTable.loading(true);
    this.listAgentFiles( true, function( data ) {
      self.agentFiles = data;
      self.agentFileListTable.setData(data);
      self.agentFileListTable.loading(false);
      self.selectionChanged();
      // 自動更新タイマーを開始
//      self.autoSave.start();
    }, null ); // TODO
  },

  add: function(){

    // ダイアログを開く
    var self = this;
    var old = agent_editor.textarea.readOnly;
    this.dialog.show( "input", {
      message : fx.template.Templates.agentEditor.add.body.evaluate({ "text" : "" }),
      init: function() {
        document.file_name_input_form.file_name_input.focus();
        if ( !agent_editor.textarea.readOnly ) {
          agent_editor.toggleReadOnly();
        }
      },
      buttons : [
        { type:"ok",
          alt: fx.template.Templates.common.button.ok,
          key: "Enter",
          action: function(dialog){
            var text = document.getElementById("file_name_input").value;
            
            // 文字列をチェック
            var error = null;
            if ( !text ) {
                error = fx.template.Templates.agentEditor.add.errormsgs.no;
            }
           if ( !error && !text.match( /^[A-Za-z0-9_\*\+\-\#\"\'\!\~\(\)\[\]\?\.]+$/ ) ) {
                error = fx.template.Templates.agentEditor.add.errormsgs.illegalChar;
            }
               // 重複チェック
            var x = self;
            if ( !error && self.agentFiles ) {
                for ( var i = self.agentFiles.length-1; i >= 0; i-- ) {
                    if ( self.agentFiles[i]["name"] == (text.match( /\.rb$/) ? text : text + ".rb")  ) {
                        error = fx.template.Templates.agentEditor.add.errormsgs.conflict;
                        break;
                    }
                }
            }
            if ( !error && !(text.match( /\.rb$/ ))  ) {
                text = text + ".rb"
            }
            if (error) {
                dialog.content.innerHTML =
                  fx.template.Templates.agentEditor.add.error.evaluate({ "error" : error.escapeHTML() })
                  + fx.template.Templates.agentEditor.add.body.evaluate({ "text" : text.escapeHTML() })
                return false;
            } else {
                self.saveFile( text, self.target, "", function(){
                    self.listAgentFiles( true, function( data ) {
                          self.agentFiles = data;
                          self.agentFileListTable.setData(data);
                          self.selectionChanged();
                        }, null ); // TODO
                }, null ); // TODO
                if ( old != agent_editor.textarea.readOnly ) {
                  agent_editor.toggleReadOnly();
                }
                return true;
            }
        } },
        { type:"cancel",
          alt: fx.template.Templates.common.button.cancel,
          key: "Esc",
          action: function(dialog){
            if ( old != agent_editor.textarea.readOnly ) {
              agent_editor.toggleReadOnly();
            }
            return true;
        }}
      ]
    } );
  },
  remove: function(){

    // 選択されている行を取得
    var selectedRowIds = this.agentFileListTable.table.getSelectedTrEls();
    if ( selectedRowIds.length <= 0 ) {
      return;
    }
    var names = [];
    for( var i=0,s=selectedRowIds.length;i<s;i++ ) {
      names.push( this.agentFileListTable.table.getRecord( selectedRowIds[i] ).getData().name);
    }
    // 確認
    var self = this;
    var old = agent_editor.textarea.readOnly;
    this.dialog.show( "input", {
      message : fx.template.Templates.agentEditor.remove.body,
      init: function() {
        if ( !agent_editor.textarea.readOnly ) {
          agent_editor.toggleReadOnly();
        }
      },
      buttons : [
        { type:"ok", 
          alt: fx.template.Templates.common.button.ok,
          key: "Enter", 
          action: function(dialog){
            if ( old != agent_editor.textarea.readOnly ) {
              agent_editor.toggleReadOnly();
            }
            // 行のデータを削除
            self.deleteFile( names, function(){
                self.listAgentFiles( true, function( data ) {
                  self.agentFiles = data;
                  self.agentFileListTable.setData(data);
                  self.selectionChanged();
                }, null ); // TODO
            }, null ); // TODO
            return true;
        }},
        { type:"cancel",
          alt: fx.template.Templates.common.button.cancel,
          key: "Esc",
          action: function(dialog){
            if ( old != agent_editor.textarea.readOnly ) {
              agent_editor.toggleReadOnly();
            }
            return true;
        }}
      ]
    });
  },
  save: function( showResult, editingFile, mode, newData ){
    var self = this;
    this.saveFile( editingFile, mode,  newData, function(result){
      // 結果を表示しない == 別画面に移動する場合は、前のコードは不要なので変更しない。
       if (!showResult) { return; }
       self.prevCode = newData;
       if ( result == "success" ) {
         document.getElementById("agent_edit_msg").innerHTML = 
           fx.template.Templates.agentEditor.saved.success.evaluate({ "now" : util.formatDate( new Date() ) });
       } else {
         document.getElementById("agent_edit_msg").innerHTML = 
           fx.template.Templates.agentEditor.saved.error.evaluate({ "now" : util.formatDate( new Date() ), "result":result.escapeHTML()} );
       }
    }, null ); // TODO
  },
  /**
   * 未保存かどうかチェックして、未保存でかつtrueであれば保存を実行する。
   */
  saveIfNotSaved: function( callback ){
    // 編集中でない
    if ( !this.editingFile ) {
      if (callback) { callback(); }
      return true; 
    }
    var editingFile = this.editingFile;
    var target = this.target;
    
    // コードが変更されていない
    var newData = agent_editor.getCode();
    newData = newData.strip();
    var self = this;
    if ( self.prevCode == newData )  { 
      if (callback) { callback(); }
      return true; 
    }
    
    // 確認ダイアログを表示
    this.dialog.show( "input", {
      message : fx.template.Templates.agentEditor.dosave,
      buttons : [
        { type:"yes", 
          alt: fx.template.Templates.common.button.yes,
          key: "Enter", 
          action: function(dialog){
            self.save(false, editingFile, target, newData);
            if (callback) { callback(); }
            return true;
        }},
        { type:"no",
          alt: fx.template.Templates.common.button.no,
          key: "Esc", 
          action: function(dialog){
            if (callback) { callback(); }
            return true;
          }
        }
      ]
    });
  },
  /**
   * 編集なし状態にします。
   */
  clearEdit : function(){
    this.editingFile = null;
    agent_editor.setCode("\n");
    this.saveButton.setEnable( false );
    document.getElementById("agent_edit_msg").innerHTML = "";
  },
  selectionChanged: function() {

    // 選択されている行を取得
    var self = this;
    var selectedRowIds = this.agentFileListTable.table.getSelectedTrEls();
    var data = null;
    var removeEnable = false;
    if ( selectedRowIds.length <= 0 ) {
      // 選択なし
      removeEnable = false;
      document.getElementById("agent-editor-file-name").innerHTML=
       fx.template.Templates.agentEditor.defaultFileName;
    } else if ( selectedRowIds.length == 1 ) {
      removeEnable = true;
      // エディタも更新する。
      data = this.agentFileListTable.table.getRecord( selectedRowIds[0] ).getData();
    } else {
      removeEnable = true;
      // エディタは初期化
      document.getElementById("agent-editor-file-name").innerHTML= "---";
    }
    //  削除の状態更新
    this.removeButton.setEnable(removeEnable);
    this.saveButton.setEnable(false);

    // エディタのデータを更新
    // 保存確認
    self.saveIfNotSaved( function(){ 
      if ( data ) {
        self.editingFile = null;
        document.getElementById("agent-editor-file-name").innerHTML=
          fx.template.Templates.common.loading;
        self.getFile( data.name, function( body ) {
          body = body.strip();
          self.editingFile = data.name;
          self.prevCode = body;
          if ( agent_editor.textarea.readOnly ) {
            agent_editor.toggleReadOnly();
          }
          if( body == "" ) body = "\n" // 空文字をcodePressに設定するとバグるので対策。
          agent_editor.setCode(body);
          agent_editor.editor.syntaxHighlight('init');
          document.getElementById("agent-editor-file-name").innerHTML= data.name;
          document.getElementById("agent_edit_msg").innerHTML = "";
          self.saveButton.setEnable( true );
        }, null ); // TODO
      } else {
        self.clearEdit();
        agent_editor.editor.syntaxHighlight('init');
        if ( !agent_editor.textarea.readOnly ) {
          agent_editor.toggleReadOnly();
        }
      }
    });
  },

  /**
   * エージェントファイルの一覧を取得する。
   * @param {Boolean} reload 再読み込みするかどうか
   * @param {Function} success 成功時のコールバック
   * @param {Function} fail 失敗時のコールバック
   */
  listAgentFiles : function( reload, success, fail ) {
    var self = this;
    if ( !this.agentClasses || reload ) {
      this.agentServiceStub.list_files( self.target, function( data ) {
        self.agentFiles = data;
        success(data);
      }, fail );
    } else {
      success(data);
    }
  },
  /**
   * エージェントファイルを取得する。
   * @param {String} file 取得するファイル
   * @param {Function} success 成功時のコールバック
   * @param {Function} fail 失敗時のコールバック
   */
  getFile : function( file, success, fail ) {
     this.agentServiceStub.get_file( file, this.target, success, fail );
  },
  /**
   * エージェントファイルを保存する。
   * @param {String} file 保存するファイル
   * @param {String} content ファイル本文
   * @param {Function} success 成功時のコールバック
   * @param {Function} fail 失敗時のコールバック
   */
  saveFile : function( file, target, content, success, fail ) {
     this.agentServiceStub.put_file( file, content, target, success, fail );
  },
  /**
   * エージェントファイルを削除する。
   * @param {String} file 削除するファイル
   * @param {Function} success 成功時のコールバック
   * @param {Function} fail 失敗時のコールバック
   */
  deleteFile : function( files, success, fail ) {
     this.agentServiceStub.delete_files( files, this.target, success, fail );
  }
}


// エージェント一覧テーブル
fx.ui.AgentFileListTable = function() {
  this.elementId = null; // @Inject
  this.table = null;
  this.ds = null;
}
fx.ui.AgentFileListTable.prototype = util.merge( util.BasicTable, {
  initialize: function() {
    var self = this;
    var columnDefs = [
      {key:"name", label:fx.template.Templates.agentEditor.fileList.column.name,
        sortable:true, resizeable:true, formatter: function( cell, record, column, data){
          cell.innerHTML =  String(data).escapeHTML();
      }, width:122},
      {key:"update", label:fx.template.Templates.agentEditor.fileList.column.update,
        sortable:true, resizeable:true, formatter: function( cell, record, column, data){
          var d = new Date(data*1000);
          cell.innerHTML =  util.formatDate(d);
      }, width:118}
    ];
    self.ds = new YAHOO.util.DataSource([]);
    self.ds.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
    self.ds.responseSchema = {
      fields: ["name","update"]
    };
    self.table = new YAHOO.widget.DataTable(self.elementId,
      columnDefs, self.ds, {
       selectionMode:"standard",
       scrollable: true,
       width:"260px"
      });
    this.setBasicActions();
  }
});