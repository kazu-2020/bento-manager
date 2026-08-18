# Ghost Form のフォームオブジェクトは素のハッシュではなく GhostForms::Submission を取る。
# テストから生のパラメータを渡すための包み紙。
#
# 対象のフォームクラスは submission_form で宣言する。
#
#   include GhostFormSubmissionHelper
#   def submission_form = ::Refunds::RefundForm
module GhostFormSubmissionHelper
  def submission(raw, form: submission_form)
    ::GhostForms::Submission.filter(raw, form: form)
  end
end
