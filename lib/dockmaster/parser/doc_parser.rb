require 'stringio'

module Dockmaster
  # Parses source code and
  # converts it into Store
  # instances for output
  class DocParser
    class << self
      def begin
        included = Dockmaster::Source.sort_source_files(Dockmaster::Source.find_all_source_files)

        store = Dockmaster::Store.new(nil, :none, '')
        included.each do |file|
          puts "Parsing #{file.sub(Dir.pwd, '')}..." if Dockmaster.debug?
          store = parse_file(file, store)
        end

        store
      end

      def parse_file(file, store)
        @file = file

        buffer = Parser::Source::Buffer.new(file)
        buffer.source = File.read(file)
        store = parse(buffer, store)

        store
      end

      def parse_string(string, store)
        @file = '<none>'

        buffer = Parser::Source::Buffer.new('(string)')
        buffer.source = string
        store = parse(buffer, store)

        store
      end

      def parse(buffer, store)
        parser = Parser::CurrentRuby.new
        parser.diagnostics.all_errors_are_fatal = true
        parser.diagnostics.ignore_warnings = true
        result_ary = parser.parse_with_comments(buffer)
        ast = result_ary[0]
        comments = result_ary[1]
        comment_locs = parse_comment_locs(comments)
        @token_lines = []
        @instance = true
        @private = false
        store = traverse_ast(ast, comment_locs, store, false)

        store
      end

      private

      def parse_comment_locs(comments)
        comment_hash = {}

        prior = -1
        comment = ''

        comments.each do |c|
          line = c.loc.line

          if line == prior + 1
            prior = line
            comment += "\n#{c.text}"
          else
            comment_hash[prior] = comment unless comment.empty?
            prior = line
            comment = c.text
          end
        end

        comment_hash[prior] = comment unless comment.empty?

        comment_hash
      end

      def traverse_ast(ast, comments, store, check_children_only = true)
        if check_children_only
          ast.children.each do |child|
            next unless child.class.to_s == 'Parser::AST::Node'
            store = perform_parse(child, comments, store)
          end
        else
          store = perform_parse(ast, comments, store)
        end

        store
      end

      def perform_parse(ast, comments, store)
        return store if ast.nil? || ast.loc.nil?
        @token_lines << ast.loc.line
        @token_lines << ast.loc.last_line
        store = if ast.type == :module
                  define_module_in_ast(ast.loc.line, ast, comments, store)
                elsif ast.type == :class
                  define_class_in_ast(ast.loc.line, ast, comments, store)
                elsif ast.type == :def
                  define_method_in_ast(ast.loc.line, ast, comments, store)
                elsif ast.type == :casgn
                  define_constant_field_in_ast(ast.loc.line, ast, comments, store)
                else
                  traverse_ast(ast, comments, store)
                end

        store
      end

      def define_module_in_ast(line, ast, comments, store)
        unless ast.children[0].nil?
          child = ast.children[0]
          if child.type == :const
            in_cache = Dockmaster::Store.in_cache?(store, :module, child.to_a[1])

            module_store = Dockmaster::Store.from_cache(store, :module, child.to_a[1])
            module_store.docs = closest_comment(line, comments)
            # priv_save = @private
            # inst_save = @instance
            # @private = false
            # @instance = true
            module_store = traverse_ast(ast, comments, module_store)
            # @private = priv_save
            # @instance = inst_save

            store.children << module_store unless in_cache
          end
        end

        store
      end

      def define_class_in_ast(line, ast, comments, store)
        unless ast.children[0].nil?
          child = ast.children[0]
          if child.type == :const
            in_cache = Dockmaster::Store.in_cache?(store, :class, child.to_a[1])

            class_store = Dockmaster::Store.from_cache(store, :class, child.to_a[1])
            class_store.docs = closest_comment(line, comments)
            # priv_save = @private
            # inst_save = @instance
            # @private = false
            # @instance = true
            # TODO: inheritance
            class_store = traverse_ast(ast, comments, class_store)
            # @private = priv_save
            # @instance = inst_save

            store.children << class_store unless in_cache
          end
        end

        store
      end

      def define_method_in_ast(line, ast, comments, store)
        ast_ary = ast.to_a
        name = ast_ary[0]
        args_ast = ast_ary[1]
        args = []

        unless args_ast.nil?
          if args_ast.type == :args
            args_ary = args_ast.to_a
            args_ary.each do |arg|
              args << arg.to_a[0] if arg.type == :arg
            end
          end
        end

        docs = closest_comment(line, comments)

        store.method_data.store(name, Dockmaster::Data.new(docs, @file, ast, line))

        store
      end

      def define_constant_field_in_ast(line, ast, comments, store)
        ast_ary = ast.to_a
        name = ast_ary[1]

        docs = closest_comment(line, comments)

        # TODO: differentiate between constants and others
        store.field_data.store(name, Dockmaster::Data.new(docs, @file, ast, line))

        store
      end

      def closest_comment_line(line, comments)
        i = line - 1
        while i > 0
          return -1 if @token_lines.include?(i)
          return i if comments.key?(i)
          i -= 1
        end
        -1
      end

      def closest_comment(line, comments)
        l = closest_comment_line(line, comments)
        return '' if l == -1
        comments[l]
      end
    end
  end
end
