require File.dirname(__FILE__) + '/../test_helper'
require 'nodes_controller'

# Re-raise errors caught by the controller.
class NodesController; def rescue_action(e) raise e end; end

class NodesControllerTest < ZenaTestController
  
  def setup
    super
    @controller = NodesController.new
    init_controller
  end
  
  def test_cache_xml_format
   without_files('/test.host/public') do
      name = "section#{nodes_zip(:people)}.xml"
      with_caching do
        assert !File.exist?("#{SITES_ROOT}/test.host/public/fr/#{name}")
        login(:lion)
        doc = secure!(Template) { Template.create("name"=>"Node", "c_format"=>"xml", "v_summary"=>"", 'v_text' => '<?xml version="1.0" encoding="utf-8"?><node><name do="[name]"/></node>', "parent_id"=>nodes_id(:default))}
        assert !doc.new_record?, "Not a new record"
        assert doc.publish
        login(:anon)
        get 'show', :prefix => 'fr', :path => [name]
        assert_response :success
        assert_equal "<?xml version=\"1.0\" encoding=\"utf-8\"?><node><name>people</name></node>", @response.body
        assert File.exist?("#{SITES_ROOT}/test.host/public/fr/#{name}")
      end
    end
  end

  def test_update_l_status
    login(:lion)
    opening = secure!(Node) { nodes(:opening) }
    art = opening.find(:first, 'set_tag')
    assert_equal 5, art.l_status
    put 'update', :id => art[:zip], :node => {:l_status => 54321}, :link_id => links_id(:opening_in_art)
    art = assigns(:node)
    assert_equal 54321, art.l_status
    # reload
    opening = secure!(Node) { nodes(:opening) }
    art = opening.find(:first, 'set_tag')
    assert_equal 54321, art.l_status
  end

  def test_ics_format_not_anon
    preserving_files('test.host/zafu') do
      login(:lion)
      doc = secure!(Template) { Template.create("name"=>"Project", "c_format"=>"ics", "v_summary"=>"", 'v_text' => "<r:notes in='site' order='event_at asc'>
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//hacksw/handcal//NONSGML v1.0//EN
<r:each>BEGIN:VEVENT
DTSTART:<r:show date='log_at' format='%Y%m%dT%H%M%S'/>
DTEND:<r:show date='event_at' format='%Y%m%dT%H%M%S'/>
SUMMARY:<r:show attr='v_title'/>
URL;VALUE=URI:<r:show attr='url'/>
END:VEVENT</r:each>
END:VCALENDAR
</r:notes>", "parent_id"=>nodes_id(:default))}
      assert !doc.new_record?, "Not a new record"
      assert doc.publish
      get 'show', :prefix => 'oo', :path => ["project#{nodes_zip(:zena)}.ics"]
      assert_response :success
      assert_match %r{parc opening.*zena enhancements}m, @response.body
    end
  end
  
  def test_cache_css_auto_publish
    login(:tiger)
    Site.connection.execute    "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:style_css_en)}"
    without_files('/test.host/public') do
      name = "textdocument#{nodes_zip(:style_css)}.css"
      filename = "#{SITES_ROOT}/test.host/public/en/#{name}"
      with_caching do
        assert !File.exist?(filename)
        get 'show', :prefix => 'en', :path => [name]
        assert_response :success
        assert File.exist?(filename) # cached page created
        assert_match %r[body \{ background: #eee; color:#444;], File.read(filename)
        put 'save_text', :id => nodes_zip(:style_css), :node => {'v_text' => '/* empty */'}
        node = assigns['node']
        assert node.errors.empty?
        assert_equal Zena::Status[:pub], node.v_status
        assert_equal versions_id(:style_css_en), node.v_id # auto publish
        assert !File.exist?(filename) # cached page removed
        get 'show', :prefix => 'en', :path => [name]
        assert_response :success
        assert_match %r[/\* empty \*/], File.read(filename)
        assert File.exist?(filename) # cached page created again
      end
    end
  end
  
end

=begin
  
  def test_import_archive
    preserving_files('test.host/data') do
      login(:tiger)
      post 'import', :archive => uploaded_archive('import.tgz'), :id => nodes_zip(:status)
      assert_response :success
      assert_template 'import'
    end
  end
  
  def test_form_tabs
    @controller = TestNodeController.new
    init_controller
    page = @controller.send(:secure, Node) { Node.find(nodes_id(:status))    }
    @controller.instance_variable_set(:@node, page)
    assert_equal [["drive", "drive"], ["links", "links"], ["help", "help"]], @controller.send(:form_tabs)
  end
  
  def test_popup_page_not_found
    get 'drive', :id=>99
    assert_redirected_to :controller => 'node', :action=>'not_found'
    get 'not_found'
    assert_template 'node/not_found'
  end
  
  
  def test_add_link
    login(:tiger)
    node = secure!(Node) { nodes(:proposition) } # Post virtual class
    assert_nil node.find(:all,'blogs')
    assert_kind_of Relation, node.relation_proxy('blog')
    post 'link', 'role'=>'blog', 'id'=>nodes_zip(:proposition), 'controller'=>'nodes', 'other_id'=>nodes_zip(:cleanWater)
    assert_response :success
    node = secure!(Node) { nodes(:proposition) } # reload
    assert blogs = node.find(:all,'blogs')
    assert_equal 1, blogs.size
    assert_equal nodes_id(:cleanWater), blogs[0][:id]
  end

  def test_tags_update_string
    login(:lion)
    post 'update', :id => nodes_zip(:art), :node => {'tagged_ids' => "#{nodes_zip(:status)}, #{nodes_zip(:people)}"}

    node = secure!(Node) { nodes(:art) }
    assert_equal 2, node.tagged.size
    stat = secure!(Node) { nodes(:status) }
    peop = secure!(Node) { nodes(:people) }
    assert_equal node[:id], stat.tags[0][:id]
    assert_equal node[:id], peop.tags[0][:id]
  end

  def test_tags_update_array
    login(:lion)
    post 'update', :id => nodes_zip(:art), :node => {:tagged_ids => [nodes_zip(:lion).to_i, nodes_zip(:cleanWater).to_s]}

    node = secure!(Node) { nodes(:art) }
    assert_equal 2, node.tagged.size
    lion = secure!(Node) { nodes(:lion) }
    clea = secure!(Node) { nodes(:cleanWater) }
    assert_equal node[:id], lion.tags[0][:id]
    assert_equal node[:id], clea.tags[0][:id]
  end
  
  def test_create_ok
    login(:tiger)
    post 'create', :node=>{:klass=>'Tracker', :parent_id=>nodes_zip(:zena), :name=>'test'}
    assert_response :success
    assert_kind_of Page, assigns['page']
    assert assigns['page'].vkind_of?('Tracker')
    assert !assigns['page'].new_record?, "Not a new record"
  end
  
  def test_bad_skin_name
    login(:anon)
    without_files('zafu') do
      Node.connection.execute "UPDATE nodes SET skin = 'bad' WHERE id = #{nodes_id(:status)}"
      assert_nothing_raised do
        get 'show', "prefix"=>"en",
         "path"=>["projects", "cleanWater", "page22.html"]
      end
    end
    assert_response :success
  end
  
  def test_find_node
    Node.connection.execute "UPDATE nodes SET name = '2006' where id = #{nodes_id(:projects)}"
    Node.connection.execute "UPDATE nodes SET name = '25-10-2006' where id = #{nodes_id(:wiki)}"
    Node.connection.execute "UPDATE nodes SET name = 'archive-1' where id = #{nodes_id(:bird_jpg)}"
    [ ['section12.html',:success],
      ['section12_tree.xml',:success],
      ['2006','page18.html'],
      ['2006.xml','page18.xml'],
      ['p12','page12.html'],
      ['25-10-2006','project29.html'],
      ['archive-1','image30.html'],
      ['archive', 404],
    ].each do |name, result|  
      puts name
      get 'show', 'prefix' => 'en', 'path' => [name]
      if result.kind_of?(String)
        assert_redirected_to 'path' => [result]
      else
        assert_response result
      end
    end
  end
  
  def test_cached_file
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        page_path = visitor.site.public_path + '/en/section12.html'
        file_path = "#{SITES_ROOT}#{page_path}"
        
        assert !File.exists?(file_path), "No cached file yet"
        assert !CachedPage.find_by_path_and_site_id(page_path, sites_id(:zena)), "No cache info yet"
        
        get 'show', 'prefix' => 'en', 'path' => ['section12.html']
        assert_response :success
        
        assert File.exists?(file_path), "Cache file created"
        assert CachedPage.find_by_path_and_site_id(page_path, sites_id(:zena))        
      end
    end
  end
  
  # test edit_... mode only if can_write?
  
end
=end