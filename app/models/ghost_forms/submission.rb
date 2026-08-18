# frozen_string_literal: true

module GhostForms
  # Ghost Form の送信を「未送信」「送信されたが読めなかった」「送信あり」の 3 状態で表す。
  #
  # 初回描画では元の販売や既存在庫から初期値を作るため、「まだ何も送られていない」と
  # 「送られたが中身が残らなかった」を見分けなければならない。フィルタ後の中身が
  # 空かどうかだけで分岐すると、不正なパラメータだけの送信が空に畳まれて初期値の
  # 再構築に化ける。返品なら修正後の販売が作られないまま元の販売が取り消されて
  # 全額返金になり、在庫訂正なら拒否すべき要求が bulk_recreate による破壊的な
  # 書き込みを行う。同型の事故なので、判定も 1 箇所に置く。
  #
  # 状態を作れるのは params を持つコントローラーだけなので生成は
  # SubmittedParamsFilterable が担い、状態の意味づけ（差し戻すかどうか）は
  # フォームが GhostForms::SubmissionReadable で担う。
  #
  # メインフォームも Ghost Form も、描画されるフィールドは商品ごとに必ず出力される
  # （数量 0 も未選択も値として送られる）。したがってフィルタ後に何も残らないのは
  # 「全て 0」ではなく壊れた送信を意味する。
  class Submission
    attr_reader :values

    # 生成は absent / filter のみ。absent と values が食い違う組み合わせを作らせない
    private_class_method :new

    class << self
      # 未送信。初回描画（new アクション）で使う
      def absent
        new(absent: true, values: {}.with_indifferent_access)
      end

      # 送信された生パラメータを、フォームが宣言した形状で検証して取り込む。
      # 検証の中身は GhostForms::ParamsFilter を参照
      def filter(raw, form:)
        return absent if raw.nil?

        new(absent: false, values: ParamsFilter.call(raw, **form::SUBMITTED_PARAMS_SHAPE))
      end
    end

    def initialize(absent:, values:)
      @absent = absent
      @values = values
    end

    # 未送信。初期値をどこから作るかの分岐にだけ使う。差し戻しの判断に使ってはいけない
    def absent?
      @absent
    end

    # 送信はあったが、必要な中身がフィルタ後に残らなかった。
    # required_keys が空なら最上位全体を、指定があればそのキーの中身を見る。
    # 何が必須かはフォームが決めるので、既定値は置かない（SubmissionReadable が渡す）
    def unreadable?(required_keys)
      return false if absent?
      return values.empty? if required_keys.empty?

      required_keys.any? { |key| values[key].blank? }
    end

    def [](key)
      values[key]
    end
  end
end
