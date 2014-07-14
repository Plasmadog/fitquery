require 'rexml/document'
require 'pathname'
require 'set'
require 'find'

# The FitnesseNode class represents a node in the Fitnesse tree, i.e. a test, suite, or static page.
# There are methods for querying tags, state, etc., which are based on the properties file.
# The content of the page is currently ignored.

# @attr_reader [FitnesseRoot] root The root of the Fitnesse tree of which this node is a part.
# @attr_reader [FitnesseNode,FitnesseRoot] parent The parent of this node (which may be the root object)
# @attr_reader [Array<FitnesseNode>] children The child nodes of this node.
# @attr_reader [Pathname] path The path of this node's folder.
# @attr_reader [String] name The name of this node. This is the "short" name of the node itself, not the fully qualified name.
# @attr_reader [Rexml::Document] properties The properties XML document of this node.
# @attr_reader [SortedSet<String>] explicit_tags The set of tags that have been explicitly set on this node.
class FitnesseNode
  attr_reader :root, :parent, :children, :path, :name, :properties, :explicit_tags


  def initialize(root, parent, name)
    @root = root
    @parent = parent
    @children = []
    @name = name.to_s
    @path = name == :root ? parent.path : Pathname.new(parent.path.join(name))
    begin
      File.open(@path.join('properties.xml'), 'r') {|f|	@properties = REXML::Document.new f	}
    rescue
      @properties = nil
    end
    begin
      tags_element = @properties.get_elements('/properties/Suites')
      unless tags_element.nil?
        @explicit_tags = SortedSet.new(tags_element.first.text.split(',').map{|tag| tag.strip })
      end
    rescue
      @explicit_tags = SortedSet.new([])
    end
    @path.children.each do |sub|
      next unless sub.directory?
      rel_path = sub.relative_path_from(@root.path)
      next if @root.blacklist.any? {|blacklisted| rel_path.fnmatch?(blacklisted) }
      child_node = FitnesseNode.new(@root, self, sub.basename)
      @children.push(child_node) unless child_node.nil?
    end
  end

  # Yield this node and its children.
  # @param order [Symbol] Use :pre to yield this node before its children, or :post to yield the children first.
  def traverse(order = :pre, &block)
    yield self if order == :pre
    unless @children.nil?
      @children.each do |child|
        child.traverse(&block)
      end
    end
    yield self if order == :post
  end

  # Yield this node and its children.
  def each(&block)
    traverse(:pre, &block)
  end

  # Yield this node and its children, but provides a way to stop further recursion down this node's branch of the tree.
  # @example Ignore all nodes that are the children of a node which is marked as skipped.
  #   start_node.find {|node|
  #     Find.prune if node.explicitly_skipped?
  #     # only gets to here if none of the current node's ancestors have been skipped.
  #   }
  def find(&block)
    catch(:prune) do
      yield self
      unless @children.nil?
        @children.each do |child|
          child.find(&block)
        end
      end
    end
  end

  # Determines the set of tags that are set on this node or any of its ancestors.
  # @return [SortedSet<String>] The set of tags that apply to this node.
  def effective_tags
    if @parent.respond_to?(:effective_tags)
      @parent.effective_tags + @explicit_tags
    else
      @explicit_tags
    end
  end

  # @return [Boolean] Does this node have the Prune property explicitly set on it?
  def explicitly_skipped?
    @properties.nil? ? false : (@properties.get_elements('/properties/Prune').count > 0)
  end

  # @return [Boolean] Does this node have the Prune property set on it or on any of its ancestors?
  def effectively_skipped?
    if @parent.respond_to?(:effectively_skipped?)
      @parent.effectively_skipped? || explicitly_skipped?
    else
      explicitly_skipped?
    end
  end

  # Gets the fully qualified name of this node.
  # @param sep [String] Sets the preferred separator string for the name. If nil, the name will use the system default file path separator.
  # @return [String] The fully qualified name of the node, consisting of the names of each node in the tree leading to this one.
  def full_name(sep = nil)
    rel_path = @path.relative_path_from(@root.path)
    if sep.nil?
      rel_path.to_s
    else
      rel_path.to_s.gsub(Pathname::SEPARATOR_PAT, sep)
    end
  end

  # Gets the depth of this node, i.e. the number of levels down the tree from the root node.
  # @return [Integer] The depth of the node
  def depth
    rel_path = @path.relative_path_from(@root.path)
    rel_path.to_s.scan(Pathname::SEPARATOR_PAT).size
  end

  # Gets the name of the node, prefixed with a number of characters determined by the node's depth.
  # Handy for displaying the node in a simple tree representation.
  # @param indent_string [String] The string from which to construct the indentation.
  # @return [String] The indented name.
  # @example A node with a full name of 'Root/Foo/Bar/Baz'
  #   node.indented_name('-')  =>  '---Baz'
  def indented_name(indent_string = ' ')
    indent = indent_string * depth
    indent + @name.to_s
  end

  # @return [Boolean] Is this node defined as a Test?
  def test?
    @properties.nil? ? false : (@properties.get_elements('/properties/Test').count > 0)
  end

  # @return [Boolean] Is this node defined as a Suite?
  def suite?
    @properties.nil? ? false : (@properties.get_elements('/properties/Suite').count > 0)
  end

  # @return [Boolean] Is this node defined as a Static page?
  def static?
    @properties.nil? ? false : (@properties.get_elements('/properties/Static').count > 0)
  end

  # @return [Boolean] Is this node runable? I.e. is it either a test or a suite which is not skipped?
  def runable?
    !static? && !effectively_skipped? && (test? || suite?)
  end

  # Determine whether this node has a particular tag on it.
  # @param tag [String,Regexp] The tag to find. If a string, the search will be case insensitive.
  #     If a regular expression is used, the regex's case sensitivity flag will be respected.
  # @param explicit_only [Boolean] Specify whether to search within the explicit tags or the effective tags of this node.
  def has_tag?(tag, explicit_only = false)
    tag_set = explicit_only ? explicit_tags : effective_tags
    if tag.instance_of?(Regexp)
      pattern = tag
    elsif tag.instance_of?(String)
      pattern = /^#{tag}$/i
    end
    tag_set.any? {|t| t.match(pattern) }
  end

  # Set a new explicit tag on the node and write it to the properties file immediately.
  # @param tag [String] The tag to add.
  def set_tag(tag)
    File.open(@path.join('properties.xml'), 'w') do |f|
      @explicit_tags.add(tag)
      suites_elements = @properties.get_elements('/properties/Suites')
      tags_element = suites_elements.empty? ? @properties.root.add_element('Suites') : suites_elements.first
      tags_element.text = @explicit_tags.to_a.join(', ')
      formatter = REXML::Formatters::Default.new
      formatter.write(@properties, f)
    end
  rescue => ex
    STDERR.puts(ex.message)
  end

  def to_s
    full_name
  end

  def <=>(other)
    if depth == other.depth
      name <=> other.name
    else
      depth <=> other.depth
    end
  end

end

