module Zena
  module Use
    module Action
      module ViewMethods
        include RubyLess
        safe_method :login_path  => String
        safe_method :logout_path => String

        # Shows 'login' or 'logout' button.
        # Is this used ? Or do we just use the zafu tag alone ?
        # def login_link(opts={})
        #   if visitor.is_anon?
        #     link_to _('login'), login_url
        #   else
        #     link_to _('logout'), logout_url
        #   end
        # end

        # Node actions that appear on the web page
        def node_actions(node, opts={})
          actions = (opts[:actions] || 'all').to_s
          actions = 'edit,propose,refuse,publish,drive' if actions == 'all'

          return '' if node.new_record?
          publish_after_save = opts[:publish_after_save]
          res = actions.split(',').reject do |action|
            !node.can_apply?(action.to_sym)
          end.map do |action|
            node_action_link(action, node, publish_after_save)
          end.join(" ")

          if res != ""
            "<span class='actions'>#{res}</span>"
          else
            ""
          end
        end

        # TODO: test
        def node_action_link(action, node, publish_after_save)
          case action
          when 'edit'
            url = edit_node_version_path(:node_id => node[:zip], :id => 0)
            "<a href='#{url}#{publish_after_save ? "?pub=#{publish_after_save}" : ''}' target='_blank' title='#{_('btn_title_edit')}' onclick=\"editor=window.open('#{url}#{publish_after_save ? "?pub=#{publish_after_save}" : ''}', \'#{current_site.host}#{node[:zip]}\', 'location=0,width=300,height=400,resizable=1');return false;\">" +
                   _('btn_edit') + "</a>"
          when 'drive'
            "<a href='#{edit_node_url(:id => node[:zip])}' target='_blank' title='#{_('btn_title_drive')}' onclick=\"editor=window.open('" +
                   edit_node_url(:id => node[:zip] ) +
                   "', '_blank', 'location=0,width=300,height=400,resizable=1');return false;\">" +
                   _('btn_drive') + "</a>"
          else
            link_to( _("btn_#{action}"), {:controller=>'versions', :action => action, :node_id => node[:zip], :id => 0}, :title=>_("btn_title_#{action}"), :method => :put )
          end
        end

        # Actions that appear in the drive popup versions list
        def version_actions(version, opts={})
          return "" unless version.kind_of?(Version)
          # 'view' ?
          actions = (opts[:actions] || 'all').to_s
          actions = 'destroy_version,remove,redit,unpublish,propose,refuse,publish' if actions == 'all'

          node = version.node

          actions.split(',').reject do |action|
            action.strip!
            if action == 'view'
              !node.can_apply?('publish', version)
            else
              !node.can_apply?(action.to_sym, version)
            end
          end.map do |action|
            version_action_link(action, version)
          end.join(' ')
        end

        # TODO: test
        def version_action_link(action,version)
          if action == 'view'
            # FIXME
            link_to_function(
            _("status_#{version.status}_img"),
            "opener.Zena.version_preview('/nodes/#{version.node.zip}/versions/#{version.number}');", :title => _("status_#{version.status}"))
          else
            if action == 'destroy_version'
              action = 'destroy'
              method = :delete
            else
              method = :put
            end
            link_to_remote( _("btn_#{action}"), :url=>{:controller=>'versions', :action => action, :node_id => version.node[:zip], :id => version.number, :drive=>true}, :title=>_("btn_title_#{action}"), :method => method ) + "\n"
          end
        end


        # TODO: test
        def discussion_actions(discussion, opt={})
          opt = {:action=>:all}.merge(opt)
          return '' unless @node.can_drive?
          if opt[:action] == :view
            link_to_function(_('btn_view'), "opener.Zena.discussion_show(#{discussion[:id]}); return false;")
          elsif opt[:action] == :all
            if discussion.open?
              link_to_remote( _("img_open"), :url=>{:controller=>'discussions', :action => 'close' , :id => discussion[:id]}, :title=>_("btn_title_close_discussion")) + "\n"
            else
              link_to_remote( _("img_closed"), :url=>{:controller=>'discussions', :action => 'open', :id => discussion[:id]}, :title=>_("btn_title_open_discussion")) + "\n"
            end +
            if discussion.can_destroy?
              link_to_remote( _("btn_remove"), :url=>{:controller=>'discussions', :action => 'remove', :id => discussion[:id]}, :title=>_("btn_title_destroy_discussion")) + "\n"
            else
              ''
            end
          end
        end
      end # ViewMethods

      module ZafuMethods
        def self.included(base)
          base.before_process :filter_actions
        end

        def r_login_link
          out "<% if visitor.is_anon? -%>"
          if dynamic_blocks?
            @markup.tag ||= 'a'
            markup = @markup.tag == 'a' ? @markup : Zafu::Markup.new('a')

            # login
            markup.set_dyn_param('href', '<%= login_url %>')
            out markup.wrap(expand_with) # will not render 'else' clause

            if else_block = descendant('else') || descendant('elsif')
              # logout
              out "<% else -%>"
              markup.done = false
              markup.set_dyn_param('href', '<%= logout_url %>')
              out markup.wrap(else_block.expand_with)
            end
          else
            out "<%= link_to #{_('login').inspect}, login_path %>"
            out "<% else -%>"
            out "<%= link_to #{_('logout').inspect}, logout_path %>"
          end
          out "<% end -%>"
        end

        def r_visitor_link
          out "<% if !visitor.is_anon? -%>"
          if dynamic_blocks?
            @markup.tag ||= 'a'
            link = '<%= user_path(visitor) %>'
            if @markup.tag == 'a'
              @markup.set_dyn_param(:href, link)
              out @markup.wrap(expand_with)
            else
              markup = Zafu::Markup.new('a')
              markup.set_dyn_param(:href, link)
              out @markup.wrap(markup.wrap(expand_with))
            end
          else
            out @markup.wrap("<%= link_to visitor.fullname, user_path(visitor) %>")
          end
          out "<% end -%>"
        end


        def filter_actions
          if actions = @params.delete(:actions)
            node = self.node
            if node.will_be? Node
            elsif node.will_be? Version
              node = "#{node}.node"
            else
              return parser_error("Invalid option 'actions' for #{node.klass}.")
            end

            if publish = @params.delete(:publish)
              out_post " <%= node_actions(#{node}, :actions => #{actions.inspect}, :publish_after_save => #{publish.inspect}) %>"
            else
              out_post " <%= node_actions(#{node}, :actions => #{actions.inspect}) %>"
            end
          end
        end
      end # ZafuMethods
    end # Action
  end # Use
end # Zena