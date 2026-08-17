# frozen_string_literal: true

require "test_helper"

module GhostForms
  class QuantitiesTest < ActiveSupport::TestCase
    test "converts the submitted shape into integer keys and values" do
      assert_equal({ 3 => 2, 5 => 0 }, Quantities.from("3" => { "quantity" => "2" }, "5" => { "quantity" => "0" }))
    end

    test "returns an empty hash for an empty submission" do
      assert_equal({}, Quantities.from({}))
    end

    test "returns an empty hash when the key did not arrive at all" do
      assert_equal({}, Quantities.from(nil))
    end

    test "returns a plain Hash for the filter's HashWithIndifferentAccess" do
      filtered = { "7" => { "quantity" => "4" } }.with_indifferent_access

      result = Quantities.from(filtered)

      assert_equal({ 7 => 4 }, result)
      assert_instance_of Hash, result
    end

    test "treats a group without quantity as zero" do
      assert_equal({ 9 => 0 }, Quantities.from("9" => {}))
    end
  end
end
