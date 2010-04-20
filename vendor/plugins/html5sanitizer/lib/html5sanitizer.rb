module HTML5Sanitizer
	require 'html5'
	require 'html5/sanitizer'
	require 'html5/treewalkers'
	require 'html5/serializer'
	include HTML5
	
	def html5sanitize(html_fragment)
		old_kcode=$KCODE
		$KCODE="NONE"
		trees = HTMLParser.parse_fragment(html_fragment, {:tokenizer => HTMLSanitizer, :encoding => 'utf-8'})
		$KCODE=old_kcode
		s = ""
		for t in trees do
			s += HTMLSerializer.serialize(TreeWalkers.get_tree_walker('rexml').new(t))
		end
		return s
	end
	
	alias hs html5sanitize
	module_function :html5sanitize, :hs
end
