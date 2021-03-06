require 'test_helper'

class PageTest < Zena::Unit::TestCase

  def test_create_just_title
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id=>nodes_id(:projects), :title=>'lazy node')}
    err node
    assert !node.new_record?
    assert_equal 'lazyNode', node.node_name
    assert_equal 'lazy node', node.title
  end

  def test_create_same_node_name
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id=>nodes_id(:projects), :node_name =>'wiki')}
    assert node.new_record?
    assert_equal 'has already been taken', node.errors[:node_name]
  end

  def test_create_same_node_name_other_parent
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id=>nodes_id(:cleanWater), :node_name =>'wiki')}
    err node
    assert ! node.new_record?, 'Not a new record'
    assert_nil node.errors[:node_name] #.empty?
  end

  def test_create_same_node_name_other_parent_with_cache
    with_caching do
      login(:tiger)
      node = secure!(Page) { Page.create(:parent_id=>nodes_id(:cleanWater), :node_name =>'wiki')}
      err node
      assert ! node.new_record?, 'Not a new record'
      assert_nil node.errors[:node_name] #.empty?
    end
  end

  def test_update_same_node_name
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    # publish so that we change node_name and check uniqueness
    assert !node.update_attributes('title' => 'wiki', :v_status => Zena::Status[:pub])
    assert_equal 'has already been taken', node.errors[:node_name]
  end

  def test_update_same_node_name_other_parent
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    node.node_name = 'wiki'
    node[:parent_id] = nodes_id(:zena)
    assert node.save
    assert_nil node.errors[:node_name] #.empty?
  end

  def test_update_same_node_name_other_parent_with_cache
    with_caching do
      login(:tiger)
      node = secure!(Node) { nodes(:cleanWater) }
      node.node_name = 'wiki'
      node[:parent_id] = nodes_id(:zena)
      assert node.save
      assert_nil node.errors[:node_name] #.empty?
    end
  end

  def test_custom_base_path
    login(:tiger)
    node = secure!(Node) { nodes(:wiki) }
    bird = secure!(Node) { nodes(:bird_jpg)}
    assert_equal '', node.basepath
    assert_equal '', bird.basepath
    assert_equal node[:id], bird[:parent_id]
    assert node.update_attributes(:custom_base => true)
    assert_equal 'projects/aWikiWithZena', node.basepath
    bird = secure!(Node) { nodes(:bird_jpg)}
    assert_equal 'projects/aWikiWithZena', bird.basepath
  end
end
