# Frozen-string-literal: true
# Copyright: 2012-2015 - MIT License
# Encoding: utf-8

require_relative "proxies"
require "forwardable"

module Jekyll
  module Assets
    module Liquid

      # Examples:
      #   - {% tag value argument:value %}
      #   - {% tag value "argument:value" %}
      #   - {% tag value argument:"I have spaces" %}
      #   - {% tag value argument:value\:with\:colon %}
      #   - {% tag value argument:"I can even escape \\: here too!" %}
      #   - {% tag value proxy:key:value %}

      class Tag
        class Parser
          attr_reader :args, :raw_args
          extend Forwardable

          def_delegator :@args, :each
          def_delegator :@args, :has_key?
          def_delegator :@args, :fetch
          def_delegator :@args, :store
          def_delegator :@args, :to_h
          def_delegator :@args, :[]=
          def_delegator :@args, :[]

          #

          Accept = {
            "css" => "text/css", "js" => "application/javascript"
          }

          #

          class UnescapedColonError < StandardError
            def initialize
              super "Unescaped double colon argument."
            end
          end

          #

          class UnknownProxyError < StandardError
            def initialize
              super "Unknown proxy argument."
            end
          end

          #

          def initialize(args, tag)
            @raw_args, @tags = args, tag
            @tag = tag
            parse_raw
            set_accept
          end

          #

          def parse_liquid!(context)
            return @args unless context.is_a?(::Liquid::Context)
            @args = _parse_liquid(@args, context)
          end

          #

          def to_html
            @args.fetch(:html, {}).map do |key, val|
              %Q{ #{key}="#{val}"}
            end. \
            join
          end

          #

          def proxies
            keys = (args.keys - Proxies.base_keys - [:file, :html])
            args.select do |key, _|
              keys.include?(key)
            end
          end

          #

          def has_proxies?
            proxies.any?
          end

          #

          private
          def parse_raw
            @args = from_shellwords.each_with_index.inject({}) do |hash, (key, index)|
              if index == 0 then hash.store(:file, key)
              elsif key =~ /:/ && (key = key.split(/(?<!\\):/))
                parse_col hash, key

              else
                (hash[:html] ||= {})[key] = \
                  true
              end

              hash
            end
          end

          #

          private
          def parse_col(hash, key)
            key.push(key.delete_at(-1).gsub(/\\:/, ":"))
            if key.size == 3 then as_proxy hash, key
              elsif key.size == 2 then as_bool_or_html hash, key
              else raise UnescapedColonError
            end
          end

          #

          private
          def as_bool_or_html(hash, key)
            okey = key; key, sub_key = key
            if Proxies.has?(key, @tag, "@#{sub_key}")
              (hash[key.to_sym] ||= {})[sub_key.to_sym] = true
            else
              (hash[:html] ||= {})[key] = \
                okey[1]
            end
          end

          #

          private
          def as_proxy(hash, key)
            key, sub_key, val = key
            if Proxies.has?(key, @tag, sub_key)
              (hash[key.to_sym] ||= {})[sub_key.to_sym] = \
                val

            elsif Proxies.has?(key)
              raise UnknownProxyError
            end
          end

          #

          private
          def set_accept
            if Accept.has_key?(@tag) && (!@args.has_key?(:sprockets) || \
                  !@args[:sprockets].has_key?(:accept))

              (@args[:sprockets] ||= {})[:accept] = \
                Accept[@tag]
            end
          end

          #

          private
          def from_shellwords
            Shellwords.shellwords(@raw_args)
          end

          #

          def _parse_liquid(hash, context)
            lqd = context.registers[:site].liquid_renderer. \
              file(raw_args)

            hash.inject({}) do |hsh, (key, val)|
              if val.is_a?(Hash) || val.is_a?(String)
                val = val.is_a?(Hash) ? _parse_liquid(val, context) : \
                  lqd.parse(val).render!(context)
              end

              hsh.update(
                key => val
              )
            end
          end
        end
      end
    end
  end
end