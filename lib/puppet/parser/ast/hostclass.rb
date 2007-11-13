require 'puppet/parser/ast/definition'

class Puppet::Parser::AST
    # The code associated with a class.  This is different from definitions
    # in that each class is a singleton -- only one will exist for a given
    # node.
    class HostClass < AST::Definition
        @name = :class

        # Are we a child of the passed class?  Do a recursive search up our
        # parentage tree to figure it out.
        def child_of?(klass)
            return false unless self.parentclass

            if klass == self.parentobj
                return true
            else
                return self.parentobj.child_of?(klass)
            end
        end

        # Evaluate the code associated with this class.
        def evaluate(options)
            scope = options[:scope]
            raise(ArgumentError, "Classes require resources") unless options[:resource]
            # Verify that we haven't already been evaluated.  This is
            # what provides the singleton aspect.
            if existing_scope = scope.compile.class_scope(self)
                Puppet.debug "Class '%s' already evaluated; not evaluating again" % (classname == "" ? "main" : classname)
                return nil
            end

            scope.compile.configuration.tag(self.classname)

            pnames = nil
            if pklass = self.parentobj
                pklass.safeevaluate :scope => scope, :resource => options[:resource]

                scope = parent_scope(scope, pklass)
                pnames = scope.namespaces
            end

            # Don't create a subscope for the top-level class, since it already
            # has its own scope.
            unless options[:resource].title == :main
                scope = subscope(scope, options[:resource])
            end

            if pnames
                pnames.each do |ns|
                    scope.add_namespace(ns)
                end
            end

            # Set the class before we do anything else, so that it's set
            # during the evaluation and can be inspected.
            scope.compile.class_set(self.classname, scope)

            # Now evaluate our code, yo.
            if self.code
                return self.code.evaluate(:scope => scope)
            else
                return nil
            end
        end

        def initialize(options)
            @parentclass = nil
            super
        end

        def parent_scope(scope, klass)
            if s = scope.compile.class_scope(klass)
                return s
            else
                raise Puppet::DevError, "Could not find scope for %s" % klass.classname
            end
        end
    end
end
