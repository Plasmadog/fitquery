require 'pathname'
require_relative 'fitnesse_node'

# The FitnesseRoot class represents an entire tree of Fitnesse tests/suites.
# @attr_reader [Pathname] path The root path of the Fitnesse tree.
# @attr_reader [Array<String>] blacklist An array of names that should be ignored during the initial tree inspection.
class FitnesseRoot
  include Enumerable
  attr_reader :path, :blacklist

  STANDARD_BLACKLIST = ["files", "FitNesse", "FrontPage", "HelpMenu", "ErrorLogs", "Recent Changes"]

  def initialize(path, blacklist = STANDARD_BLACKLIST)
    @path = Pathname.new(path)
    @blacklist = blacklist
    @root_node = FitnesseNode.new(self, self, :root)
  end

  # Print a summary of the entire tree, indicating types, skipped status, and effective tags on each node.
  def print_summary
    traverse do |node|
      print node.effectively_skipped? ? '-' : '+'
      case
        when node.test? then print 'T'
        when node.suite? then print 'S'
        when node.static? then print 'X'
        else print '?'
      end
      print node.indented_name('  ')
      tags = node.effective_tags.to_a
      unless tags.empty?
        # highlight the tags that are explicit on this node
        tags = tags.map {|tag| node.explicit_tags.include?(tag) ? "*#{tag}" : tag }
        print "  [#{tags.join(',')}]"
      end
      print "\n"
    end
  end

  def traverse(order = :pre, &block)
    @root_node.traverse(order, &block)
  end

  def each(&block)
    @root_node.traverse(:pre, &block)
  end

  def find(&block)
    @root_node.find(&block)
  end
end


