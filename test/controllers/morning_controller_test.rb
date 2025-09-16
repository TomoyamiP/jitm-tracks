require "test_helper"

class MorningControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get morning_index_url
    assert_response :success
  end
end
