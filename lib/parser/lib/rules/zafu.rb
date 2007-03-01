require File.join(File.dirname(__FILE__) , 'zena')

module Zafu
  module Tags
    
    def render(context={})
      @context = context
      @html_tag_done = false
      unless @html_tag
        if @params[:id] || @params[:class]
          @html_tag = @params[:tag] || 'div'
          @params.delete(:tag)
          @html_tag_params = {}
          [:id, :class].each do |k|
            @html_tag_params[k] = @params[k] if @params[k]
            @params.delete(k)
          end
        end
      end
      res = super
      if (@context[:parts] || {})[@context[:name]]
        res
      else
        render_html_tag(res)
      end
    end
    
    def inspect
      @html_tag_done = false
      res = super
      if @html_tag && !@html_tag_done
        if res =~ /\A\[(\w+)(.*)\/\]\Z/
          res = "[#{$1}#{$2}]<#{@html_tag}/>[/#{$1}]"
        elsif res =~ /\A\[([^\]]+)\](.*)\[\/(\w+)\]\Z/
          res = "[#{$1}]#{render_html_tag($2)}[/#{$3}]"
        end
        @html_tag_done = true
      end
      res
    end
    
    def params_to_html(params)
      para = []
      params.each do |k,v|
        para << " #{k}=#{params[k].inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
      end
      para.sort.join('')
    end
    
    def render_html_tag(text)
      return text unless @html_tag && !@html_tag_done
      res = "<#{@html_tag}#{params_to_html(@html_tag_params || {})}"
      if text != ''
        res << ">#{text}</#{@html_tag}>"
      else
        res << "/>"
      end
      @html_tag_done = true
      res
    end
    
    def r_rename_asset
      return expand_with unless @html_tag
      unless @params[:src][0..0] == '/'
        case @html_tag
        when 'link'
          if @params[:rel].downcase == 'stylesheet'
            @params[:src] = @options[:helper].send(:template_url_for_asset, :stylesheet , @params[:src])
          else
            @params[:src] = @options[:helper].send(:template_url_for_asset, :link, @params[:src])
          end
        else
          @params[:src] = @options[:helper].send(:template_url_for_asset, @html_tag.to_sym , @params[:src])
        end
      end
      res   = "<#{@html_tag}#{params_to_html(@params)}"
      @html_tag_done = true
      inner = expand_with
      if inner == ''
        res + "/>"
      else
        res + ">#{inner}"
      end
    end
  end
end

module Zafu
  module Rules
    def start(mode)
      # html_tag
      if @html_tag = @options[:html_tag]
        @options.delete(:html_tag)
        @html_tag_params = parse_params(@options[:html_tag_params])
        @options.delete(:html_tag_params)
      end
      
      # end_tag
      @end_tag = @html_tag || @options[:end_do] || "z:#{@method}"
      @end_tag_count  = 1
      
      if @params =~ /\A([^>]*?)do\s*=('|")([^\2]*?[^\\])\2([^>]*)\Z/  
        # we have a sub 'do'
        @params = parse_params($1)
        opts = {:method=>$3, :params=>$4}
        
        # the matching zafu tag will be parsed by the last 'do', we must inform it to halt properly :
        opts[:end_do] = @end_tag
        
        make(:void, opts)
        if @method == 'include'
          include_template
        end
      else  
        @params = parse_params(@params)
        if @method == 'include'
          include_template
        elsif mode == :tag
          scan_tag
        else
          enter(mode)
        end
      end
      
      if !@html_tag && (@html_tag = @params[:tag])
        @params.delete(:tag)
        # get html tag parameters from @params
        @html_tag_params = {}
        [:class, :id].each do |k|
          next unless @params[k]
          @html_tag_params[k] = @params[k]
          @params.delete(k)
        end
      end
    end
    
    def before_parse(text)
      text.gsub('<%', '&lt;%').gsub('%>', '%&gt;')
    end
  
    # scan rules
    def scan
      # puts "SCAN(#{@method}): [#{@text}]"
      if @text =~ /\A([^<]*)</
        flush $1
        if @text[1..1] == '/'
          scan_close_tag
        elsif @text[0..3] == '<!--'
          scan_html_comment
        else
          scan_tag
        end
      else
        # no more tags
        flush
      end
    end
  
    def scan_close_tag
      if @text =~ /\A<\/([^>]+)>/
        # puts "CLOSE:[#{$&}]}" # ztag
        # closing tag
        if $1 == @end_tag
          @end_tag_count -= 1
          if @end_tag_count == 0
            eat $&
            leave
          else  
            # keep the tag (false alert)
            flush $&
          end
        elsif $1[0..1] == 'z:'
          # /ztag
          eat $&
          if $1 != @end_tag
            # error bad closing ztag
            store "<span class='parser_error'>#{$&.gsub('<', '&lt;').gsub('>','&gt;')}</span>"
          end
          leave
        else  
          # other html tag closing
          flush $&
        end
      else
        # error
        flush
      end
    end

    def scan_html_comment
      if @text =~ /<!--\|(.*?)-->/m
        # zafu html escaped
        eat $&
        @text = $1 + @text
      elsif @text =~ /<!--.*?-->/m
        # html comment
        flush $&
      else
        # error
        flush
      end
    end
  
    def scan_tag
      # puts "TAG(#{@method}): [#{@text}]"
      if @text =~ /\A<z:(\w+)([^>]*?)(\/?)>/
        # puts "ZTAG:[#{$&}]}" # ztag
        eat $&
        opts = {:method=>$1, :params=>$2}
        opts.merge!(:text=>'') if $3 != ''
        make(:void, opts)
      elsif @text =~ /\A<(\w+)([^>]*?)do\s*=('|")([^\3]*?[^\\])\3([^>]*?)(\/?)>/
        # puts "DO:[#{$&}]}" # do tag
        eat $&
        opts = {:method=>$4, :html_tag=>$1, :html_tag_params=>$2, :params=>$5}
        opts.merge!(:text=>'') if $6 != ''
        make(:void, opts)
      elsif @end_tag && @text =~ /\A<#{@end_tag}([^>]*?)(\/?)>/
        # puts "SAME:[#{$&}]}" # simple html tag same as end_tag
        flush $&
        @end_tag_count += 1 unless $2 == '/'
      elsif @text =~ /\A<(link|img|script).*src\s*=/
        # puts "HTML:[#{$&}]}" # html
        make(:asset)
      elsif @text =~ /\A[^>]*?>/
        # html tag
        flush $&
      else
        # never closed tag
        flush
      end
    end
    
    def scan_asset
      # puts "ASSET(#{object_id}) [#{@text}]"
      if @text =~ /\A<(\w*)([^>]*?)(\/?)>/
        matched = $&
        eat $&
        @method = 'rename_asset'
        @html_tag = @end_tag = $1
        closed = ($3 != '')
        @params = parse_params($2)
        if closed
          leave(:asset)
        else
          enter(:inside_asset)
        end
      else
        # error
        @method = 'void'
        flush
      end
    end
    
    def scan_inside_asset
      if @text =~ /\A(.*?)<\/#{@end_tag}>/
        flush $&
        leave(:asset)
      else
        # never ending asset
        flush
      end
    end
  end
end