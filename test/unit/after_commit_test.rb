# Simple integration test for the after_commit plugin
require 'test_helper'

class AfterCommitTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = false

  class Page < ActiveRecord::Base
    set_table_name :nodes
    attr_accessor :actions
    before_save :do_action
    after_save  :raise_to_rollback
    validates_presence_of :node_name

    def after_commit_actions
      @after_commit_actions ||= []
    end

    private
      def do_action
        self[:user_id] = 0
        after_commit do
          after_commit_actions << 'executed'
        end
      end

      def raise_to_rollback
        raise ActiveRecord::Rollback if self[:node_name] == 'raise'
      end
  end

  def test_after_commit_actions_should_be_executed_after_commit
    page = Page.create(:node_name => 'hello')
    assert_equal ['executed'], page.after_commit_actions
  end

  def test_after_commit_actions_should_be_executed_after_last_transaction
    page = nil
    Page.transaction do
      page = Page.create(:node_name => 'hello')
      assert_equal [], page.after_commit_actions
    end
    assert_equal ['executed'], page.after_commit_actions
  end

  def test_after_commit_actions_should_not_be_executed_on_failure
    page = Page.create
    assert page.new_record?
    assert_equal [], page.after_commit_actions
  end

  def test_after_commit_actions_should_not_be_executed_on_raise
    page = Page.create(:node_name => 'raise')
    assert_equal [], page.after_commit_actions
  end

  def test_after_commit_actions_should_not_be_executed_if_an_outer_transaction_fails
    page = nil
    begin
      Page.transaction do
        page = Page.create(:node_name => 'hello')
        assert_equal [], page.after_commit_actions
        raise 'Something went bad'
      end
    rescue Exception => err
    end
    assert_equal [], page.after_commit_actions
  end

  def test_after_commit_actions_should_not_be_executed_when_a_rollback_is_raised
    page = nil
    Page.transaction do
      page = Page.create(:node_name => 'hello')
      assert_equal [], page.after_commit_actions
      raise ActiveRecord::Rollback
    end
    assert_equal [], page.after_commit_actions
  end

  def test_after_commit_should_be_cleared_after_transaction
    actions = []
    Page.transaction do
      Page.after_commit do
        actions << 'executed'
      end
      raise ActiveRecord::Rollback
    end
    assert_equal [], actions

    Page.transaction do
    end
    assert_equal [], actions
  end

  def test_should_not_insert_after_commit_outside_of_a_transaction
    assert_raise(Exception) do
      Page.new.instance_eval do
        after_commit do
          # never executed
        end
      end
    end
  end
end
