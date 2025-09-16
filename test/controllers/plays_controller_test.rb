require "test_helper"

class PlaysControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get plays_index_url
    assert_response :success
  end
end
