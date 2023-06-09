# frozen_string_literal: true

module RuboCop
  module Cop
    module Performance
      # Identifies the use of `Regexp#match` or `String#match`, which
      # returns `#<MatchData>`/`nil`. The return value of `=~` is an integral
      # index/`nil` and is more performant.
      #
      # @example
      #   # bad
      #   do_something if str.match(/regex/)
      #   while regex.match('str')
      #     do_something
      #   end
      #
      #   # good
      #   method(str =~ /regex/)
      #   return value unless regex =~ 'str'
      class RedundantMatch < Base
        extend AutoCorrector

        MSG = 'Use `=~` in places where the `MatchData` returned by `#match` will not be used.'
        RESTRICT_ON_SEND = %i[match].freeze

        # 'match' is a fairly generic name, so we don't flag it unless we see
        # a string or regexp literal on one side or the other
        def_node_matcher :match_call?, <<~PATTERN
          {(send {str regexp} :match _)
           (send !nil? :match {str regexp})}
        PATTERN

        def_node_matcher :only_truthiness_matters?, <<~PATTERN
          ^({if while until case while_post until_post} equal?(%0) ...)
        PATTERN

        def on_send(node)
          return unless match_call?(node) &&
                        (!node.value_used? || only_truthiness_matters?(node)) &&
                        !(node.parent && node.parent.block_type?)

          add_offense(node) do |corrector|
            autocorrect(corrector, node) if autocorrectable?(node)
          end
        end

        private

        def autocorrect(corrector, node)
          new_source = "#{node.receiver.source} =~ #{node.first_argument.source}"

          corrector.replace(node, new_source)
        end

        def autocorrectable?(node)
          # Regexp#match can take a second argument, but this cop doesn't
          # register an offense in that case
          node.receiver.regexp_type? || node.first_argument.regexp_type?
        end
      end
    end
  end
end
