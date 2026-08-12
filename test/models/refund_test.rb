require "test_helper"

class RefundTest < ActiveSupport::TestCase
  fixtures :locations, :employees, :sales, :refunds

  test "validations" do
    @subject = refunds(:partial_refund)

    must validate_presence_of(:refund_datetime)
    must validate_presence_of(:amount)
    must validate_numericality_of(:amount).only_integer
  end

  test "associations" do
    @subject = Refund.new

    must belong_to(:original_sale).class_name("Sale")
    must belong_to(:corrected_sale).class_name("Sale").optional
    must belong_to(:employee).optional
  end
end
