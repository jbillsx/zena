require File.dirname(__FILE__) + '/../test_helper'
CachedPage
class CachedPage
  def randomize_visited_nodes!
    @expire_with = (200 * rand).to_i.times { ids << (500000 * rand).to_i}
  end
end
class CachedPageTest < ZenaTestUnit

  def test_create
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        secure!(Node) { nodes(:status) }
        secure!(Node) { nodes(:bird_jpg) }
        assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], visitor.visited_node_ids
        path = "#{SITES_ROOT}#{visitor.site.public_path + "/some/place.html"}"
        assert !File.exists?(path), "No cached file yet"
        cache = secure!(CachedPage) { CachedPage.create(
          :path => (visitor.site.public_path + "/some/place.html"),
          :expire_after  => nil,
          :content_data => "this is the cached content") }
        assert File.exists?(path), "Cache file created"
        data = File.open(path) {|f| f.read }
        assert_equal "this is the cached content", data
        assert_equal ["12", "20"], cache.node_ids
        # test expire
        login(:tiger)
        node = secure!(Node) { nodes(:status) }
        
        assert node.update_attributes(:v_title=>'hey'), "Can save"
        assert !File.exists?(path), "Cache file removed"
        assert_equal [], cache.node_ids
      end
    end
  end
  
  def test_create_symlink
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        node = secure!(Node) { nodes(:bird_jpg) }
        path = "#{SITES_ROOT}#{visitor.site.public_path + "/some/place/image12.jpg"}"
        assert !File.exists?(path), "No cached file yet"
        cache = secure!(CachedPage) { CachedPage.create(
          :path => (visitor.site.public_path + "/some/place/image12.jpg"),
          :expire_after  => nil,
          :content_path  => node.c_filepath) }
        assert File.exists?(path), "Cache file created"
        assert File.symlink?(path), "Cache file is a symlink"
        # test expire
        login(:tiger)
        node = secure!(Node) { nodes(:bird_jpg) }
        assert node.update_attributes(:v_title=>'hey'), "Can save"
        assert !File.exists?(path), "Cache file removed"
      end
    end
  end
  
  def test_expire_old
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        secure!(Node) { nodes(:status) }
        secure!(Node) { nodes(:bird_jpg) }
        assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], visitor.visited_node_ids
        path = "#{SITES_ROOT}#{visitor.site.public_path + "/some/place.html"}"
        assert !File.exists?(path), "No cached file yet"
        cache = secure!(CachedPage) { CachedPage.create(
          :path => (visitor.site.public_path + "/some/place.html"),
          :expire_after  => Time.now - 3600,
          :content_data => "this is the cached content") }
        assert File.exists?(path), "Cache file created"
        data = File.open(path) {|f| f.read }
        assert_equal "this is the cached content", data
        assert_equal ["12", "20"], cache.node_ids
        # test expire
        CachedPage.expire_old
        assert !File.exists?(path), "Cache file removed"
        assert_equal [], cache.node_ids
      end
    end
  end
  
  def test_site_id
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        secure!(Node) { nodes(:people) }
        cache = secure!(CachedPage) { CachedPage.create(
          :path => (visitor.site.public_path + "/some/place.html"),
          :expire_after  => nil,
          :content_data => "this is the cached content") }
        assert !cache.new_record?, "Not a new record"
        assert_equal sites_id(:zena), cache[:site_id]
      end
    end
  end
  
  def test_cannot_set_site_id
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        secure!(Node) { nodes(:people) }
        assert_raise(Zena::AccessViolation) do
          cache = secure!(CachedPage) { CachedPage.create(
            :path         => (visitor.site.public_path + "/some/place.html"),
            :expire_after => nil,
            :content_data => "this is the cached content",
            :site_id      => sites_id(:ocean))}

        end
        cache = secure!(CachedPage) { CachedPage.create(
          :path         => (visitor.site.public_path + "/some/place.html"),
          :expire_after => nil,
          :content_data => "this is the cached content") }

        assert !cache.new_record?, "Not a new record"
        assert_raise(Zena::AccessViolation) { cache.site_id = sites_id(:ocean) }
        assert_equal sites_id(:zena), cache[:site_id]
      end
    end
  end
  
  def test_create_for_zafu_template
    without_files('test.host/zafu') do
      login(:anon)
      template_ids = [nodes_id(:Node_index_html), nodes_id(:Project_html), nodes_id(:layout_html), nodes_id(:notes_html)]
      path = SITES_ROOT + visitor.site.zafu_path + "/default/Node_index.html/en/main.erb"
      assert !File.exists?(path), "No cached file yet"
      cache = secure!(CachedPage) { CachedPage.create(
        :path            => (visitor.site.zafu_path + "/default/Node_index.html/en/main.erb"),
        :expire_after    => nil,
        :expire_with_ids => template_ids,
        :content_data    => "this is the cached content") }
      assert File.exists?(path), "Cache file created"
      data = File.open(path) {|f| f.read }
      assert_equal "this is the cached content", data
      assert_equal template_ids, cache.node_ids.map{|i| i.to_i}
      # test expire
      login(:tiger)
      node = secure!(Node) { nodes(:layout_html) }
      assert node.update_attributes(:v_title=>'hey'), "Can save"
      assert !File.exists?(path), "Cache file removed"
      assert_equal [], cache.node_ids
    end
  end
end