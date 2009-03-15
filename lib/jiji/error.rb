
module JIJI
  # 致命的エラー
  class FatalError < StandardError
    def initialize( code, message="" )
      super( message )
      @code = code
    end
    attr :code
  end
  # ユーザー操作により発生しうるエラー
  class UserError < StandardError
    def initialize( code, message="" )
      super( message )
      @code = code
    end
    attr :code
  end

  # エラーコード:存在しない
  ERROR_NOT_FOUND = "not_found"
  # エラーコード:すでに存在する
  ERROR_ALREADY_EXIST = "already_exist"

  # エラーコード:不正な名前
  ERROR_ILLEGAL_NAME = "illegal_name"

  # エラーコード:想定外エラー
  ERROR_FATAL = "fatal"

  # エラーコード:サーバーに接続されていない
  ERROR_NOT_CONNECTED = "not_connected"
end