# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.object_src  :none

    # 画像・アイコンはすべて Vite が自ドメインから配信する（data: は inline SVG 用）
    policy.img_src :self, :data

    # JS も自ドメインのみ。Chartkick が出すインラインスクリプトは nonce で許可する
    policy.script_src :self

    # Google Fonts のスタイルシートと本体。
    # 棒グラフの幅と Icon の CSS 変数を style 属性で渡しているため 'unsafe_inline' が要る。
    # style 属性だけを許す style_src_attr もあるが、非対応ブラウザでは style-src に
    # フォールバックして style 属性が丸ごと効かなくなる。CSS による情報漏洩の経路は
    # img_src が :self に絞られていて塞がっているので、互換性を優先して style-src 側で許可する。
    policy.style_src :self, :https, :unsafe_inline
    policy.font_src  :self, :https, :data

    if Rails.env.development?
      # @vite/client が HMR でアセットを配信・接続できるようにする
      vite_host = ViteRuby.config.host_with_port
      vite_origin = "http://#{vite_host}"

      policy.script_src(*policy.script_src, :unsafe_eval, vite_origin)
      policy.style_src(*policy.style_src, vite_origin)
      policy.img_src(*policy.img_src, vite_origin)
      policy.font_src(*policy.font_src, vite_origin)
      policy.connect_src(:self, vite_origin, "ws://#{vite_host}")
    end
  end

  # Chartkick のインラインスクリプトと Turbo が参照する nonce。
  # Turbo がキャッシュしたスナップショットを復元しても一致するよう、セッション単位で固定する。
  # ログイン前などセッション ID がまだない画面では空文字になってしまうため、都度生成に切り替える
  # （空の nonce はどのインラインスクリプトとも一致せず、実行時にだけ壊れる）。
  config.content_security_policy_nonce_generator = lambda do |request|
    request.session.id.to_s.presence || SecureRandom.base64(16)
  end

  # style-src には nonce を付けない。nonce があるとブラウザが 'unsafe-inline' を無視し、
  # 棒グラフの幅や Icon コンポーネントの CSS 変数を渡している style 属性が効かなくなる。
  config.content_security_policy_nonce_directives = %w[script-src]
end
