# frozen_string_literal: true

require "test_helper"

module GhostForms
  class SubmissionTest < ActiveSupport::TestCase
    # 実物の宣言を参照する。写すとフォーム側の変更に気付けない
    CART_FORM = ::Sales::CartForm
    REFUND_FORM = ::Refunds::RefundForm

    def filter(raw, form: CART_FORM)
      Submission.filter(ActionController::Parameters.new(cart: raw)[:cart], form: form)
    end

    test "パラメータが無ければ未送信" do
      submission = Submission.filter(nil, form: CART_FORM)

      assert_predicate submission, :absent?
      assert_not submission.unreadable?
      assert_empty submission.values
    end

    test "absent は未送信を表す" do
      submission = Submission.absent

      assert_predicate submission, :absent?
      assert_not submission.unreadable?
    end

    test "送信されて中身が残れば、未送信でも読めなくもない" do
      submission = filter({ "12" => { "quantity" => "3" }, "customer_type" => "citizen" })

      assert_not submission.absent?
      assert_not submission.unreadable?
      assert_equal "3", submission["12"]["quantity"]
    end

    # 「送信されたが空」を未送信と同じに畳むと、初期値の再構築や
    # 「全て0」の確定に化ける（Submission のコメント参照）
    test "宣言に合わない値だけの送信は、未送信ではなく読めない送信になる" do
      submission = filter({ "abc" => { "quantity" => "1" } })

      assert_not submission.absent?
      assert_predicate submission, :unreadable?
      assert_empty submission.values
    end

    test "未送信は読めない送信として扱わない" do
      assert_not Submission.absent.unreadable?
      assert_not Submission.absent.unreadable?(%w[corrected])
    end

    test "必須キーを宣言すると、そのキーの中身だけを見る" do
      submission = Submission.filter(
        ActionController::Parameters.new(
          refund: { "coupon" => { "5" => { "quantity" => "1" } } }
        )[:refund],
        form: REFUND_FORM
      )

      # 最上位は空ではないが、corrected が無い以上「修正後の数量」は読めていない
      assert_not submission.values.empty?
      assert_not submission.unreadable?
      assert submission.unreadable?(%w[corrected])
    end

    test "必須キーの中身が残っていれば読める送信" do
      submission = Submission.filter(
        ActionController::Parameters.new(
          refund: { "corrected" => { "7" => { "quantity" => "0" } } }
        )[:refund],
        form: REFUND_FORM
      )

      assert_not submission.unreadable?(%w[corrected])
    end
  end
end
