
// ネームスペース
namespace( "fx.template" )

fx.template.Templates = {
  common: {
    loading : '<img src="./img/loading.gif"  alt="loading.." title="loading.." />',
    date: {
      d:"日", m:"月", y:"年",
      h:"時間", mm: "分", s:"秒"
    },
    button : {
      start: "開始",
      apply  : "適用",
      update : "更新",
      add : "追加",
      del : "削除",
      save : "保存",
      ok  : "OK",
      cancel: "キャンセル",
      yes  : "はい",
      no: "いいえ"
    }
  },
  agentSelector: {
    error : new Template( '<div class="problem">※#{error}</div>#{msg}')
  },
  agentEditor: {
    topicPath: {
      agent: "エージェント:エージェントの作成/編集",
      sharedLib: "エージェント:共有ライブラリの作成/編集"
    },
    desc: {
        agent: "※エージェントを作成・編集します。一覧からファイルを選択して編集、または追加ボタンから追加して下さい。<br/>"
          + "※改変後のコードは次にエージェントを使用した場合に有効になります。",
        sharedLib:  "※共有ライブラリを作成・編集します。一覧からファイルを選択して編集、または追加ボタンから追加して下さい。<br/>"
          + "※改変後のコードは次にライブラリのクラスや関数を使用した場合に有効になります。"
    },
    saved : {
      error : new Template(
          '<span class="problem">※コンパイルエラー</span> <span style="color: #FF3366;">( #{now} ) <br/>' +
          ' #{result}</span>'),
      success : new Template('※保存しました。 ( #{now} )')
    },
    dosave : "未保存のデータがあります。保存しますか?",
    add : {
      error : new Template(
        '<div class="problem">※#{error}</div>'
      ),
      body : new Template(
        "追加するファイル名を入力してください。<br/>" +
        '<form action="javascript:void(0);" name="file_name_input_form">' +
        '  <input id="file_name_input" name="file_name_input" type="text"' +
        '    style="width:360px;margin-top:10px;" value="#{text}" />'+
        '</form>'),
      errormsgs : {
        no          : "ファイル名が入力されていません。",
        illegalChar : "ファイル名が不正です。半角英数字、および「-_*+-#![]()?\.」のみ使用可能です。",
        conflict    : "ファイル名が重複しています。"
      }
    },
    remove: {
      body : "ファイルを削除します。削除したファイルは復元できません。<br/>よろしいですか?"
    },
    defaultFileName: "( ファイルを選択してください。 )",
    fileList : {
      column : {
        name : "名前",
        update : "最終更新日時"
      }
    }
  },
  agentPropertyEditor: {
    none: new Template(
      'エージェントを選択してください。' ),
    selected: new Template(
      '<form id="agent-property-editor-form_#{id}" name="agent-property-editor-form_#{id}" action="javascript:return false;">' +
      '  <div class="item">'+
      '    <div class="title">名前</div>' +
      '    <div class="value"><input name="agent_name" id="agent_name" type="text" value="#{name}"/></div>'+
      '  <div class="property-problem" id="agent_name_problem"></div>' +
      '  </div>' +
      '  <div class="item">'+
      '    <div class="title">クラス</div>' +
      '    <div class="value">' +
      '     #{class_name}<pre>#{desc}</pre>'+
      '    </div>'+
      '  </div>' +
      '  <div class="item">'+
      '    <div class="title">プロパティ</div>' +
      '    <div class="value"><div class="property-container">' +
      '     #{properties}' +
      '    </div></div>'+
      '  </div>' +
      '</form>' ),
      selectedReadOnly: new Template(
          '  <div class="item">'+
          '    <div class="title">名前</div>' +
          '    <div class="value">#{name}</div>'+
          '  </div>' +
          '  <div class="item">'+
          '    <div class="title">クラス</div>' +
          '    <div class="value">' +
          '     #{class_name}<pre>#{desc}</pre>'+
          '    </div>'+
          '  </div>' +
          '  <div class="item">'+
          '    <div class="title">プロパティ</div>' +
          '    <div class="value"><div class="property-container">' +
          '     #{properties}' +
          '    </div></div>'+
          '  </div>'  ),
    property: new Template(
      '<div class="propery">'+
      '  <div class="property-description">#{name}</div>' +
      '  <input class="property-input" name="property_#{id}" id="property_#{id}"  type="text" value="#{default}" />'+
      '  <div class="property-problem" id="property_#{id}_problem"></div>' +
      '</div>' ),
    propertyReadOnly: new Template(
      '<div class="propery">'+
      '  <div class="property-description">#{name}</div>' +
      '  <div class="property-value">#{default} </div>'+
      '</div>' )
  },
  sidebar : {
    process : new Template (
      '  <div class="name"><span id="process_#{id}_name">#{name} </span><span class="process_delete"><a href="javascript:fx.app.sideBar.remove(\'#{id}\');" id="process_#{id}_delete">[削除]</a></span></div>' +
      '  <div class="detail">'+
      '    <div class="date">#{date}</div>' +
      '    <div class="state" id="process_#{id}_state">状態:#{state}</div>' +
      '    <div class="progress" id="process_#{id}_progress">' +
      '      <div class="progress_bar" id="process_#{id}_progress_bar"></div>' +
      '      <div class="progress_value" id="process_#{id}_progress_value"></div>' +
      '      <div class="breaker"></div>' +
      '    </div>' +
      '  </div>')
  },
  btcreate : {
    dateSummary : {
      notSelect: "※開始日、終了日を選択して下さい。",
      selected: new Template('<table class="values small" style="width:360px;" cellspacing="0" cellpadding="0">' +
      '            <tr><td class="label small" >期間</td><td class="value">#{range}</td></tr>' +
      '            <tr><td class="label small" >推定所要時間</td><td class="value">#{time} </td></tr>' +
      '        </table>'),
      error: "<span class='problem'>※開始日、終了日の設定が不正です。</span>"
    },
    start : {
      error: new Template("<span class='problem'>※テストの開始に失敗しました。" +
      		"<pre style='width:350px;height:200px;overflow:scroll;font-size:11px;font-weight:normal'>#{error}</pre>" +
      		"</span>")
    }
  },
  rtsetting : {
    apply: {
        error: new Template("<span class='problem'>※設定の反映に失敗しました。" +
            "<pre style='width:350px;height:200px;overflow:scroll;font-size:11px;font-weight:normal'>#{error}</pre>" +
            "</span>")
      }
  },
  submenu : {
    info : {
      info : new Template(
          '  <table class="values large" cellspacing="0" cellpadding="0">' +
          '     <tr><td class="label large">名前</td><td class="value">#{name}</td></tr>' +
          '     <tr><td class="label large">期間</td><td class="value">#{range}</td></tr>' +
          '     <tr><td class="label large">メモ</td><td class="value"><pre>#{memo}</pre></td></tr>' +
          '  </table>'),
      rmtInfo : new Template(
          '  <table class="values large" cellspacing="0" cellpadding="0">' +
          '     <tr><td class="label large">自動取引</td><td class="value">#{enable}</td></tr>' +
          '  </table>')
    },
    trade : {
      summary : new Template (
          '<div id="summary" style="margin-top:10px;">'+
          '  <table class="values large" cellspacing="0" cellpadding="0">' +
          '     <tr><td class="label large">損益合計</td><td class="value">#{totalProfitOrLoss}</td></tr>' +
          '     <tr><td class="label large">累計スワップ</td><td class="value">#{totalSwap}</td></tr>' +
          '     <tr><td class="label large">総取引回数/約定済み</td><td class="value">#{total}/#{commited}</td></tr>' +
          '  </table>' +
          '  <div>' +
          '     <div style="float:left;width:300px;">' +
          '        <div class="category">種類</div>'+
          '        <table class="values small" cellspacing="0" cellpadding="0">' +
          '            <tr><td class="label small" >売</td><td class="value">#{sell}</td></tr>' +
          '            <tr><td class="label small" >買</td><td class="value">#{buy}</td></tr>' +
          '        </table>' +
          '        <div class="category">勝敗</div>'+
          '        <table class="values small" cellspacing="0" cellpadding="0">' +
          '            <tr><td class="label small" >勝ち/負け/引分</td><td class="value">#{win}/#{lose}/#{draw}</td></tr>' +
          '            <tr><td class="label small" >勝率</td><td class="value">#{winRate}%</td></tr>' +
          '        </table>' +
          '        <div class="category">通貨ペア</div>' +
          '        <table class="values small" cellspacing="0" cellpadding="0">' +
          '            #{pair}' +
          '        </table>' +
          '     </div>' +
          '     <div style="float:right;width:300px;">' +
          '        <div class="category">損益</div>'+
//          '        <div class="item"><div class="label_2">最大ドローダウン</div><div class="value">#{drawdown}</div><div class="breaker"></div></div>'+
          '        <table class="values small" cellspacing="0" cellpadding="0">' +
          '            <tr><td class="label small" >最大利益</td><td class="value">#{maxProfit}</td></tr>' +
          '            <tr><td class="label small" >最大損失</td><td class="value">#{maxLoss}</td></tr>' +
          '            <tr><td class="label small" >平均損益</td><td class="value">#{avgProfitOrLoss}</td></tr>' +
          '            <tr><td class="label small" >平均利益</td><td class="value">#{avgProfit}</td></tr>' +
          '            <tr><td class="label small" >平均損失</td><td class="value">#{avgLoss}</td></tr>' +
          '            <tr><td class="label small" >損益率</td><td class="value">#{profitRatio}</td></tr>' +
          '        </table>' +
          '        <div class="category">取引量</div>'+
          '        <table class="values small" cellspacing="0" cellpadding="0">' +
          '            <tr><td class="label small" >最大取引量</td><td class="value">#{maxSize}</td></tr>' +
          '            <tr><td class="label small" >最小取引量</td><td class="value">#{minSize}</td></tr>' +
          '        </table>' +
          '        <div class="category">建玉保有期間</div>'+
          '        <table class="values small" cellspacing="0" cellpadding="0">' +
          '            <tr><td class="label small" >最大保有期間</td><td class="value">#{maxRange}分</td></tr>' +
          '            <tr><td class="label small" >最小保有期間</td><td class="value">#{minRange}分</td></tr>' +
          '            <tr><td class="label small" >平均保有期間</td><td class="value">#{avgRange}分</td></tr>' +
          '        </table>' +
          '     </div>' +
          '   <div class="breaker"></div></div>' +
          '</div>'),
      pair : new Template (
          '<tr><td class="label small" >#{pair}</td><td class="value">#{value}</td></tr>' )
    },
    graph : {
      agent : new Template(
          '  <div class="agent">#{agentName}</div>'+
          '  <table class="graphs" cellspacing="0" cellpadding="0">' +
          '      #{items}'+
          '  </table>'),
      item : new Template(
          '     <tr>' +
          '       <td>' +
          '         <input  type="checkbox"  alt="グラフを表示"  #{checked} id="submenu-graph_checked_#{id}" />' +
          '         <label for="submenu-graph_checked_#{id}" title="#{name}">#{name}</label>' +
          '       </td>' +
          '       <td class="color">#{colors}</td>'+
          '     </tr>' )
    }
  }
}
