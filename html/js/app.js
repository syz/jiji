
// ネームスペース
namespace( "fx" );


// 定数
fx.constants = {
  SERVICE_URI : "./json"
}

fx.initialize = function(){
  fx.container = new container.Container( function( binder ){

    // App
    binder.bind( fx.Application ).to( "app" ).inject({
      pageManager: container.component("pageManager"),
      sideBar:     container.component("sideBar")
    });

    // page manager
    binder.bind( util.PageManager ).to( "pageManager" ).initialize( function( obj, container ) {
        obj.init( container.gets("pages"));
    });

    // pages
    binder.bind( fx.ui.pages.RtSettingPage ).to( "pages" ).inject({
    	id : "rt_setting",
    	elementId : "page-rt-setting",
    	agentSelector: container.component("rtSettingAgentSelector"),
    	processServiceStub: container.component("processServiceStub"),
    	topicPath: container.component("topicPath"),
    	tradeEnable: container.component("tradeEnable"),
    	dialog : container.component("dialog")
    }).initialize( function( obj, container ) {
      obj.initialize( );
    });
    binder.bind( fx.ui.pages.AgentEditorPage ).to( "pages" ).inject({
    	id : "agent_edit",
    	elementId : "page-agent-edit",
    	agentServiceStub: container.component("agentServiceStub"),
    	agentFileListTable: container.component("agentFileListTable"),
    	topicPath: container.component("topicPath"),
    	dialog : container.component("dialog")
    });
    binder.bind( fx.ui.pages.BtCreatePage ).to( "pages" ).inject({
      id : "bt_create",
      elementId : "page-bt-create",
      agentSelector: container.component("btCreateAgentSelector"),
      processServiceStub: container.component("processServiceStub"),
      rateServiceStub: container.component("rateServiceStub"),
      topicPath: container.component("topicPath"),
      sideBar: container.component("sideBar"),
      dialog : container.component("dialog")
    }).initialize( function( obj, container ) {
      obj.initialize( );
    });
    binder.bind( fx.ui.pages.ResultPage ).to( "pages" ).inject({
      id : "result",
      elementId : "page-result",
      processServiceStub: container.component("processServiceStub"),
      pageManager: container.component("resultPageManager"),
      topicPath: container.component("topicPath"),
      sideBar: container.component("sideBar"),
      dialog : container.component("dialog")
    }).initialize( function( obj, container ) {
      obj.initialize( );
    });

    // page manager (結果一覧ページ用)
    binder.bind( util.PageManager ).to( "resultPageManager" ).initialize( function( obj, container ) {
        obj.init( container.gets("result_pages"));
    });
    binder.bind( fx.ui.pages.LogResultPage ).to( "result_pages" ).inject({
      id : "log",
      elementId : "subpage-log",
      outputServiceStub: container.component("outputServiceStub")
    });
    binder.bind( fx.ui.pages.TradeResultPage ).to( "result_pages" ).inject({
      id : "trade",
      elementId : "subpage-trade",
      tradeResultServiceStub: container.component("tradeResultServiceStub"),
      dialog : container.component("dialog")
    });
    binder.bind( fx.ui.pages.InfoResultPage ).to( "result_pages" ).inject({
      id : "info",
      elementId : "subpage-info",
      processServiceStub: container.component("processServiceStub"),
      agentSelector: container.component("subpageInfoAgentSelector"),
      dialog : container.component("dialog")
    }).initialize( function( obj, container ) {
      obj.initialize( );
    });
    binder.bind( fx.ui.pages.GraphSettingResultPage ).to( "result_pages" ).inject({
      id : "graph",
      elementId : "subpage-graph",
      processServiceStub: container.component("processServiceStub"),
      outputServiceStub: container.component("outputServiceStub"),
      dialog : container.component("dialog")
    });

    // agent editor
    binder.bind( fx.agent.ui.AgentSelector ).to( "rtSettingAgentSelector" ).inject({
      id: "rt-setting_as",
      agentServiceStub: container.component("agentServiceStub"),
      dialog : container.component("dialog")
    });
    binder.bind( fx.agent.ui.AgentSelector ).to( "btCreateAgentSelector" ).inject({
      id: "bt-create_as",
      agentServiceStub: container.component("agentServiceStub"),
      dialog : container.component("dialog")
    });
    binder.bind( fx.agent.ui.AgentSelector ).to( "subpageInfoAgentSelector" ).inject({
      id: "subpage-info_as",
      agentServiceStub: container.component("agentServiceStub"),
      dialog : container.component("dialog")
    });

    // agent-edit
    binder.bind( fx.ui.AgentFileListTable ).to( "agentFileListTable" ).inject({
      elementId : "agent-file-list"
    });

    // side-bar
    binder.bind( fx.ui.SideBar ).to( "sideBar" ).inject({
      elementId : "back-tests",
      pageManager:     container.component("pageManager"),
      processServiceStub: container.component("processServiceStub"),
      dialog : container.component("dialog")
    }).initialize( function( obj, container ) {
      obj.initialize();
    });

    // topicPath
    binder.bind( util.TopicPath ).to( "topicPath" ).inject({
      elementId : "topic_path"
    });

    // tradeEnable
    binder.bind( fx.ui.TradeEnable ).to( "tradeEnable" ).inject({
      elementId : "head_trade_enable",
      processServiceStub: container.component("processServiceStub")
    }).initialize( function( obj, container ) {
      obj.init();
    });

    // dialog
    binder.bind( util.Dialog ).to( "dialog" );

    // stub
    binder.bindProvider( function() {
      return JSONBrokerClientFactory.createFromList(
        fx.constants.SERVICE_URI + "/agent",
        ["list_agent_class",
         "put_file",
         "delete_files",
         "list_agent",
         "add_agent",
         "remove_agent",
         "off",
         "on",
         "list_files",
         "get_file"] );
    } ).to("agentServiceStub");

    binder.bindProvider( function() {
      return JSONBrokerClientFactory.createFromList(
        fx.constants.SERVICE_URI + "/process",
        ["list_test",
         "get",
         "set",
         "new_test",
         "status",
         "delete_test",
         "stop",
         "restart"] );
    } ).to("processServiceStub");
    binder.bindProvider( function() {
      return JSONBrokerClientFactory.createFromList(
        fx.constants.SERVICE_URI + "/output",
        [ "get_log", "list_outputs", "set_properties" ] );
    } ).to("outputServiceStub");
    binder.bindProvider( function() {
      return JSONBrokerClientFactory.createFromList(
        fx.constants.SERVICE_URI + "/trade_result",
        [ "list" ] );
    } ).to("tradeResultServiceStub");
    binder.bindProvider( function() {
      return JSONBrokerClientFactory.createFromList(
        fx.constants.SERVICE_URI + "/rate",
        [ "range" ] );
    } ).to("rateServiceStub");
  });
  fx.app = fx.container.get( "app" );
  fx.app.initialize();

}


fx.Application = function() {
  this.agentSelector = null; //@Inject
  this.pageManager = null; //@Inject
}
fx.Application.prototype = {

  /**
   * 初期化
   */
  initialize : function (  ) {

    var self = this;
    this.sideBar.to("sidebar_result_rmt");
  },

  /**
   * エラーがあれば表示する。
   * @param {Object} arg1 パラメータ
   * @param {Object} arg2 パラメータ
   */
  showError: function(arg1, arg2){
  	alert("error:" + arg1 + " " +arg2 );
  }
}

function debug(str) {
  document.getElementById('debug').innerHTML += str + "<br/>";
}
