require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  # sales は「グラフが描画される販売先」を用意するために必要
  fixtures :employees, :locations, :sales

  test "画面には XSS を緩和する CSP ヘッダーが付く" do
    login_as_employee(:verified_employee)

    get locations_path

    assert_response :success

    directives = csp_directives

    assert_not_empty directives, "Content-Security-Policy ヘッダーが送出されていること"
    assert_equal [ "'none'" ], directives["object-src"]
    assert_includes directives["script-src"], "'self'"
    assert_not_includes directives["script-src"], "'unsafe-inline'",
                        "インラインスクリプトを一括で許可すると CSP の意味がなくなる"
    assert_not_includes directives["script-src"], "https:",
                        "JS は Vite が自ドメインから配信するので外部 https を許可しない"

    # 棒グラフの幅と Icon の CSS 変数を style 属性で渡しているため、style だけは例外
    assert_includes directives["style-src"], "'unsafe-inline'"
    assert_empty directives["style-src"].grep(/\A'nonce-/),
                 "style-src に nonce があると 'unsafe-inline' が無視され、style 属性が壊れる"
  end

  test "グラフのインラインスクリプトは nonce で許可され CSP 下でも実行できる" do
    login_as_employee(:verified_employee)

    get location_path(locations(:city_hall))

    assert_response :success

    header_nonces = csp_directives["script-src"].grep(/\A'nonce-/)

    assert_equal 1, header_nonces.size, "script-src に nonce が 1 つ含まれること"

    inline_nonces = css_select("script[nonce]").map { |script| "'nonce-#{script["nonce"]}'" }

    assert_not_empty inline_nonces, "グラフのインラインスクリプトが描画されていること"
    assert_equal header_nonces, inline_nonces.uniq, "インラインスクリプトの nonce がヘッダーと一致すること"
  end

  test "セッションがまだない画面でも nonce は空にならない" do
    get "/employee/login"

    assert_response :success

    nonce = csp_directives["script-src"].grep(/\A'nonce-/).first

    assert_not_equal "'nonce-'", nonce, "空の nonce はどのインラインスクリプトとも一致しない"
  end

  private

  def csp_directives
    response.headers["Content-Security-Policy"].to_s.split(";").to_h do |directive|
      name, *sources = directive.split
      [ name, sources ]
    end
  end
end
