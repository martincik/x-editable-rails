require 'base64'

module X
  module Editable
    module Rails
      module ViewHelpers
        #
        # Options determine how the HTML tag is rendered and the remaining options are converted to data-* attributes.
        #
        # options:
        #   tag:   tag name of element returned
        #   class: "class" attribute on element
        #   placeholder: "placeholder" attribute on element
        #   title: "title" attribute on element (defaults to placeholder)
        #   data:  "data-*" attributes on element
        #     source: a Hash of friendly display values used by input elements based on (object) value
        #       - boolean shorthand ['Enabled', 'Disabled'] becomes { '1' => 'Enabled', '0' => 'Disabled' }
        #       - enumerable shorthand ['Yes', 'No', 'Maybe'] becomes { 'Yes' => 'Yes', 'No' => 'No', 'Maybe' => 'Maybe' }
        #     classes: a Hash of classes to add based on the value (same format and shorthands as source)
        #   value: override the object's value
        #   
        def editable(object, method, options = {})
          options = Configuration.method_options_for(object, method).deep_merge(options).with_indifferent_access
          # merge data attributes for backwards-compatibility
          options.merge! options.delete(:data){ Hash.new }
          
          url     = options.delete(:url){ polymorphic_path(object) }
          object  = object.last if object.kind_of?(Array)
          value   = options.delete(:value){ object.send(method) }
          value_formatter = options.delete(:value_formatter)
          source  = options[:source] ? format_source(options.delete(:source), value) : default_source_for(value)
          classes = format_source(options.delete(:classes), value)
          error   = options.delete(:e)
          html_options = options.delete(:html){ Hash.new }
          
          if xeditable?(object)
            model   = object.class.name.split('::').last.underscore
            nid     = options.delete(:nid)
            nested  = options.delete(:nested)
            title   = options.delete(:title) do
              klass = nested ? object.class.const_get(nested.to_s.singularize.capitalize) : object.class
              klass.human_attribute_name(method)
            end
            
            output_value = output_value_for(value)
            css_list = options.delete(:class).to_s.split(/\s+/).unshift('editable')
            css_list << classes[output_value] if classes
            type = options.delete(:type){ default_type_for(value) }
            
            css   = css_list.compact.uniq.join(' ')
            tag   = options.delete(:tag){ 'span' }
            placeholder = options.delete(:placeholder){ title }
            
            # any remaining options become data attributes
            data  = {
              type:   type,
              model:  model, 
              name:   method, 
              value:  ( type == 'wysihtml5' ? Base64.encode64(output_value) : output_value ), 
              placeholder: placeholder, 
              classes: classes, 
              source: source, 
              url:    url, 
              nested: nested, 
              nid:    nid
            }.merge(options)
            
            data.reject!{|_, value| value.nil?}

            html_options.update({
              class: css,
              title: title,
              data: data
            })
            
            content_tag tag, html_options do
              safe_join(source_values_for(value.try(:html_safe), source), tag(:br)) unless %w(select checklist).include? data[:type]
            end
          else
            error || safe_join(formated_source_values_for(value, value_formatter, source), tag(:br))
          end
        end
        
        private
        
        def output_value_for(value, formatter = nil)
          case value
          when TrueClass
            '1'
          when FalseClass
            '0'
          when Array
            value.map{|item| output_value_for item}.join(',')
          else
            value.to_s
          end
        end

        def formated_source_values_for(value, formatter, source = nil)
          values = source_values_for(value, source)
          if formatter && formatter.is_a?(Proc)
            values = values.map { |value| formatter.call(value) }
          end
          values
        end
        
        def source_values_for(value, source = nil)
          source ||= default_source_for value
          values = Array.wrap(value)
          
          if source
            if source.is_a? Proc
              values.map { |item| source.call(item) }
            elsif source.respond_to?(:[])
              values.map { |item| source[item] }
            end
          else
            values
          end
        end
        
        def default_type_for(value)
          case value
          when TrueClass, FalseClass
            'select'
          when Array
            'checklist'
          else
            'text'
          end
        end
        
        def default_source_for(value)
          case value
          when TrueClass, FalseClass
            { '1' => 'Yes', '0' => 'No' }
          end
        end
        
        # helper method that take some shorthand source definitions and reformats them
        def format_source(source, value)
          formatted_source = case value
            when TrueClass, FalseClass
              if source.is_a?(Array) && source.first.is_a?(String) && source.size == 2
                { '1' => source[0], '0' => source[1] }
              end
            when String
              if source.is_a?(Array) && source.first.is_a?(String)
                source.inject({}){|hash, key| hash.merge(key => key)}
              elsif source.is_a?(Hash)
                source
              end
            end
          
          formatted_source || source
        end
        
      end
    end
  end
end
